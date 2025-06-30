// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CloudKit
import Common

final class ModificationBatchQueue {
    private let batchElementLimit = 399
    
    private var batchModify: [[CKRecord]] = []
    private var batchDelete: [[CKRecord.ID]] = []
    
    private var batchCount: Int = 0
    
    var finished: Bool {
        batchCount < 0
    }
    
    func setRecordsToModifyOnServer(_ modify: [CKRecord]?, deleteIDs: [CKRecord.ID]?) {
        if let modify {
            batchModify = modify.grouped(by: batchElementLimit)
        }
        
        if let deleteIDs {
            batchDelete = deleteIDs.grouped(by: batchElementLimit)
        }
        
        let maxBatchCount = max(batchModify.count, batchDelete.count)
        batchCount = maxBatchCount - 1
        
        Log("ModificationBatchQueue - spliting into \(maxBatchCount) batches", module: .cloudSync)
    }
    
    func currentBatch() -> (modify: [CKRecord]?, delete: [CKRecord.ID]?) {
        let modify = batchModify[safe: batchCount]
        let delete = batchDelete[safe: batchCount]
        return (modify: modify, delete: delete)
    }
    
    func prevBatchProcessed() {
        batchCount -= 1
    }
    
    func clear() {
        batchCount = 0
        batchModify = []
        batchDelete = []
    }
}
