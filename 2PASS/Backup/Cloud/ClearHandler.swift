// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import CloudKit

final class ClearHandler {
    private let cloudKit = CloudKit()
    private var isClearing = false
    private var batchCount: Int = 0
    private let batchElementLimit = 399

    var didClear: Callback?
    
    func clear(recordIDs: [CKRecord.ID]) {
        guard !isClearing else { return }
        Log("ClearHandler - Deleting 2PASS Cloud Backup", module: .cloudSync)
        isClearing = true
        cloudKit.changesSavedSuccessfuly = { [weak self] in
            guard let self, batchCount > 0, isClearing else { return }
            batchCount -= 1
            Log("ClearHandler - Batch Delete Saved Successfuly", module: .cloudSync)
            if batchCount == 0 {
                Log("ClearHandler - All Entries Deleted Successfuly", module: .cloudSync)
                changesSavedSuccessfuly()
            }
        }
        
        let batch = recordIDs.grouped(by: batchElementLimit)
        batchCount = batch.count
        for i in 0..<batchCount {
            cloudKit.modifyRecord(recordsToSave: nil, recordIDsToDelete: batch[i])
        }
    }
    
    private func changesSavedSuccessfuly() {
        isClearing = false
        Log("ClearHandler - Deletition of 2PASS Cloud Backup was successful", module: .cloudSync)
        cloudKit.clear()
        didClear?()
    }
}
