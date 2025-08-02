// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CloudKit
import Common

final class ModificationBatchQueue {
    private let batchElementLimit = 400
    
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
        
        let maxBatchCount = batchModify.count + batchDelete.count
        batchCount = maxBatchCount - 1
        
        Log("ModificationBatchQueue - spliting into \(maxBatchCount) batches", module: .cloudSync)
    }
    
    func currentBatch() -> (modify: [CKRecord]?, delete: [CKRecord.ID]?) {
        if let delete = batchDelete.popLast() {
            return (modify: nil, delete: delete)
        }
        if let modify = batchModify.popLast() {
            return (modify: modify, delete: nil)
        }
        return (modify: nil, delete: nil)
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
