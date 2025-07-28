// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CloudKit
import Common

public protocol CloudRecovering: AnyObject {
    func listVaultsToRecover(completion: @escaping (Result<[VaultRawData], Error>) -> Void)
    func deleteVault(id: VaultID) async throws
}

public final class CloudRecovery: CloudRecovering {
    private var database: CKDatabase {
        container.privateCloudDatabase
    }
    
    private(set) lazy var container: CKContainer = { // lazy for avoid autofill extension crash
        CKContainer(identifier: Config.containerIdentifier)
    }()
    
    private var vaults: [VaultRawData] = []
    private var completion: ((Result<[VaultRawData], Error>) -> Void)?
    
    private let resultLimit = 100
    
    public init() {
    }
    
    public func listVaultsToRecover(completion: @escaping (Result<[VaultRawData], Error>) -> Void) {
        vaults = []
        self.completion = completion
        Log("CloudRecovery - listing Vaults")
        
        let predicate = NSPredicate(value: true)
        let query = CKQuery(recordType: RecordType.vault.rawValue, predicate: predicate)
        let queryOperation = CKQueryOperation(query: query)

        queryOperation.database = database

        queryOperation.resultsLimit = resultLimit
        queryOperation.queuePriority = .veryHigh

        queryOperation.recordMatchedBlock = recordMatchedBlock
        queryOperation.queryResultBlock = queryResultBlock

        database.add(queryOperation)
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
    
    func recordMatchedBlock(_ recordID: CKRecord.ID, _ result: Result<CKRecord, any Error>) -> Void {
        switch result {
        case .success(let record):
            if record.recordType == RecordType.vault.rawValue, let vault = VaultRecord(record: record).toRawData() {
                vaults.append(vault)
            }
        case .failure(let error):
            Log("CloudRecovery - Error while listing Vaults \(error)")
        }
    }
    
    func queryResultBlock(_ result: Result<CKQueryOperation.Cursor?, any Error>) -> Void {
        switch result {
        case .success(let cursor):
            if let cursor {
                self.fetchMoreRecords(cursor: cursor)
            } else {
                Log("CloudRecovery - Query completed!")
                
                let sortedVaults = vaults.sorted(by: { $0.updatedAt > $1.updatedAt })
                
                DispatchQueue.main.async {
                    self.completion?(.success(sortedVaults))
                }
            }
        case .failure(let error):
            DispatchQueue.main.async {
                self.completion?(.failure(error))
            }
        }
    }
        
    func fetchMoreRecords(cursor: CKQueryOperation.Cursor) {
        let nextOperation = CKQueryOperation(cursor: cursor)
        
        nextOperation.recordMatchedBlock = recordMatchedBlock
        nextOperation.queryResultBlock = queryResultBlock
        nextOperation.resultsLimit = resultLimit
        nextOperation.queuePriority = .veryHigh
        
        database.add(nextOperation)
    }
}

