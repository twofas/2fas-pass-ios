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

    private var batches: [(modify: [CKRecord], delete: [CKRecord.ID])] = []

    var finished: Bool {
        batches.isEmpty
    }

    func setRecordsToModifyOnServer(_ modify: [CKRecord]?, deleteIDs: [CKRecord.ID]?) {
        let allModify = modify ?? []
        let allDelete = deleteIDs ?? []

        batches = []

        var modifyIndex = allModify.startIndex
        var deleteIndex = allDelete.startIndex

        while modifyIndex < allModify.endIndex || deleteIndex < allDelete.endIndex {
            let remaining = batchElementLimit

            let modifyEnd = min(modifyIndex + remaining, allModify.endIndex)
            let modifyBatch = Array(allModify[modifyIndex..<modifyEnd])
            modifyIndex = modifyEnd

            let deleteRemaining = remaining - modifyBatch.count
            let deleteEnd = min(deleteIndex + deleteRemaining, allDelete.endIndex)
            let deleteBatch = Array(allDelete[deleteIndex..<deleteEnd])
            deleteIndex = deleteEnd

            batches.append((modify: modifyBatch, delete: deleteBatch))
        }

        Log("ModificationBatchQueue - spliting into \(batches.count) batches", module: .cloudSync)
    }

    func currentBatch() -> (modify: [CKRecord]?, delete: [CKRecord.ID]?) {
        guard let batch = batches.first else {
            return (modify: nil, delete: nil)
        }
        return (
            modify: batch.modify.isEmpty ? nil : batch.modify,
            delete: batch.delete.isEmpty ? nil : batch.delete
        )
    }

    func prevBatchProcessed() {
        if !batches.isEmpty {
            batches.removeFirst()
        }
    }

    func clear() {
        batches = []
    }
}
