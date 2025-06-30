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
            if let cursor = cursor {
                self.fetchMoreRecords(cursor: cursor)
            } else {
                Log("CloudRecovery - Query completed!")
                // TODO: Remove some time after release
                // Filtering the pre-zone Vault
                let vaults = self.vaults
                let oldZone = CKRecordZone.ID(zoneName: "TwoPassZone", ownerName: CKCurrentUserDefaultName)
                let filteredVaults = vaults.filter({ $0.zoneID != oldZone })
                
                let sortedVaults = filteredVaults.sorted(by: { $0.updatedAt > $1.updatedAt })
                
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

