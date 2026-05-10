// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CloudKit
import Common

public protocol CloudRecovering: AnyObject {
    func listVaultsToRecover() async throws -> [VaultRawData]
    func deleteVault(id: VaultID) async throws
}

public final class CloudRecovery: CloudRecovering {
    private var database: CKDatabase {
        container.privateCloudDatabase
    }

    private(set) lazy var container: CKContainer = { // lazy for avoid autofill extension crash
        CKContainer(identifier: Config.containerIdentifier)
    }()

    private let resultLimit = 100

    public init() {}

    public func listVaultsToRecover() async throws -> [VaultRawData] {
        Log("CloudRecovery - listing Vaults")
        return try await withCheckedThrowingContinuation { continuation in
            let session = ListSession(
                continuation: continuation,
                database: database,
                resultLimit: resultLimit
            )
            let predicate = NSPredicate(value: true)
            let query = CKQuery(recordType: RecordType.vault.rawValue, predicate: predicate)
            session.run(CKQueryOperation(query: query))
        }
    }

    public func deleteVault(id: VaultID) async throws {
        Log("CloudKit - deleting zone", module: .cloudSync)
        do {
            try await database.deleteRecordZone(withID: .from(vaultID: id))
            Log("CloudKit - deleting zone - success", module: .cloudSync)
        } catch {
            Log("CloudKit - deleting zone - handling error: \(error)", module: .cloudSync)
            throw error
        }
    }
}

// Per-call session that owns the accumulator and the single-shot continuation. Keeps
// `CloudRecovery` itself stateless so concurrent callers can't collide on shared instance
// state (the previous completion-handler implementation stored `vaults` and `completion`
// on the class — a second call would clobber an in-flight first call).
private final class ListSession {
    private let continuation: CheckedContinuation<[VaultRawData], Error>
    private let database: CKDatabase
    private let resultLimit: Int
    private var vaults: [VaultRawData] = []
    private var resumed = false

    init(
        continuation: CheckedContinuation<[VaultRawData], Error>,
        database: CKDatabase,
        resultLimit: Int
    ) {
        self.continuation = continuation
        self.database = database
        self.resultLimit = resultLimit
    }

    func run(_ operation: CKQueryOperation) {
        operation.database = database
        operation.resultsLimit = resultLimit
        operation.queuePriority = .veryHigh

        // Strong self capture is intentional: the session owns its own lifetime until it
        // resumes the continuation. With `[weak self]` the local `session` in the
        // continuation body is the only strong reference, so the session would deallocate
        // before CloudKit fires its callbacks — leaking the continuation.
        operation.recordMatchedBlock = { _, result in
            switch result {
            case .success(let record):
                if record.recordType == RecordType.vault.rawValue,
                   let vault = VaultRecord(record: record).toRawData() {
                    self.vaults.append(vault)
                }
            case .failure(let error):
                Log("CloudRecovery - Error while listing Vaults \(error)")
            }
        }

        operation.queryResultBlock = { result in
            switch result {
            case .success(let cursor):
                if let cursor {
                    self.run(CKQueryOperation(cursor: cursor))
                } else {
                    Log("CloudRecovery - Query completed!")
                    let sortedVaults = self.vaults.sorted(by: { $0.updatedAt > $1.updatedAt })
                    self.resume(returning: sortedVaults)
                }
            case .failure(let error):
                self.resume(throwing: error)
            }
        }

        database.add(operation)
    }

    private func resume(returning vaults: [VaultRawData]) {
        guard !resumed else { return }
        resumed = true
        continuation.resume(returning: vaults)
    }

    private func resume(throwing error: Error) {
        guard !resumed else { return }
        resumed = true
        continuation.resume(throwing: error)
    }
}
