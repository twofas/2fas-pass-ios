// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common
import CloudKit

typealias EntityOfKind = (entityID: String, type: RecordType)

final class SyncHandler {
    private let mergeHandler: MergeHandler
    private let cacheHandler: CacheHandler
    private let cloudKit: CloudKit
    private let modifyQueue: ModificationBatchQueue
    
    private var isSyncing = false
    private var applyingChanges = false
    private var currentDate = Date()
        
    typealias OtherError = (NSError) -> Void
    
    var startedSync: Callback?
    var finishedSync: Callback?
    var refreshLocalData: Callback?
    var otherError: OtherError?
    var quotaExceeded: Callback?
    var userDisabledCloud: Callback?
    var useriCloudProblem: Callback?
    
    var container: CKContainer { cloudKit.container }
    
    init(
        mergeHandler: MergeHandler,
        cacheHandler: CacheHandler,
        cloudKit: CloudKit,
        modifyQueue: ModificationBatchQueue
    ) {
        self.mergeHandler = mergeHandler
        self.cacheHandler = cacheHandler
        self.cloudKit = cloudKit
        self.modifyQueue = modifyQueue
                
        cloudKit.deletedEntries = { [weak self] entries in self?.deleteEntries(entries) }
        cloudKit.updatedEntries = { [weak self] entries in self?.updateEntries(entries) }
        cloudKit.fetchFinishedSuccessfuly = { [weak self] in self?.fetchFinishedSuccessfuly() }
        cloudKit.changesSavedSuccessfuly = { [weak self] in self?.changesSavedSuccessfuly() }
        
        cloudKit.resetStack = { [weak self] in
            Log("SyncHandler - resetStack", module: .cloudSync)
            self?.resetStack()
        }
        cloudKit.userLoggedOut = { [weak self] in
            Log("SyncHandler - userLoggedOut based on error", module: .cloudSync)
            self?.useriCloudProblem?()
        }
        cloudKit.quotaExceeded = { [weak self] in
            Log("SyncHandler - Quota exceeded!", module: .cloudSync)
            self?.quotaExceeded?()
        }
        cloudKit.userDisablediCloud = { [weak self] in
            Log("SyncHandler - User disabled iCloud!", module: .cloudSync)
            self?.userDisabledCloud?()
        }
        cloudKit.useriCloudProblem = { [weak self] in
            Log("SyncHandler - User has problem with iCloud - check settings!", module: .cloudSync)
            self?.useriCloudProblem?()
        }
    }
    
    func setCurrentDate(_ date: Date) {
        currentDate = date
    }
    
    func firstStart() {
        Log("SyncHandler - first start!", module: .cloudSync)
        
        mergeHandler.clear()
        cacheHandler.purge()
        modifyQueue.clear()
        ConstStorage.clearZone()
    }
    
    func synchronize(zoneID: CKRecordZone.ID) {
        guard !isSyncing else {
            Log("SyncHandler - Can't start sync. Already in progress. Exiting", module: .cloudSync)
            return
        }
        Log("SyncHandler - Sync Handler: synchronizing", module: .cloudSync)
        isSyncing = true
        startedSync?()
        
        mergeHandler.clear()
        modifyQueue.clear()
        cloudKit.cloudSync(zoneID: zoneID)
    }
    
    func clearCacheAndDisable() {
        Log("SyncHandler - Sync Handler: clearCacheAndDisable", module: .cloudSync)
        isSyncing = false
        resetStack()
        cloudKit.clear()
    }
    
    // MARK: - Private
    
    private func updateEntries(_ entries: [CKRecord]) {
        Log("SyncHandler - Sync Handler: update entries: \(entries.count)", module: .cloudSync)
        cacheHandler.updateOrCreate(with: entries)
    }
    
    private func deleteEntries(_ entries: [(name: String, type: String)]) {
        Log("SyncHandler - Sync Handler: delete entries: \(entries.count)", module: .cloudSync)
        let entries: [EntityOfKind] = entries.compactMap { entityID, type in
            guard let type = RecordType(rawValue: type) else { return nil }
            return (entityID: entityID, type: type)
        }
        cacheHandler.deleteEntries(entries)
    }
    
    // swiftlint:disable line_length
    private func fetchFinishedSuccessfuly() {
        cacheHandler.commitChanges()
        
        Log("SyncHandler - method: fetch finished successfuly", module: .cloudSync)
        guard isSyncing else { return }
        Log("SyncHandler -  merging now with local database", module: .cloudSync)
        mergeHandler.setItemIDsForDeletition(cacheHandler.itemIDsForDeletition) // used for migration to Items
        mergeHandler.merge(date: currentDate) { [weak self] result in
            switch result {
            case .success:
                guard self?.mergeHandler.hasChanges == true else {
                    Log("SyncHandler - No logs with changes. Exiting", module: .cloudSync)
                    self?.applyingChanges = false
                    self?.syncCompleted()
                    return
                }
                self?.applyMerge()
            case .failure(let error):
                Log("SyncHandler: error while merging: \(error)", module: .cloudSync, severity: .error)
                switch error {
                case .incorrectEncryption, .newerVersion: self?.otherError?(error as NSError)
                case .noLocalVault, .mergeError, .syncNotAllowed: self?.resetStack()
                }
            }
        }
    }
    
    private func applyMerge() {
        guard isSyncing else {
            Log("SyncHandler - apply and merge stopped", module: .cloudSync)
            return
        }
        Log("SyncHandler - applying local changes", module: .cloudSync)
                
        let changes = mergeHandler.changesForCloud()

        let recordsToModifyOnServer = changes.createUpdate.isEmpty ? nil : changes.createUpdate
        let recordIDsToDeleteOnServer = changes.delete.isEmpty ? nil : changes.delete
        
        Log("SyncHandler - Change records: deletition: \(String(describing: recordIDsToDeleteOnServer?.count)), modification: \(String(describing: recordsToModifyOnServer?.count))", module: .cloudSync)
        
        guard recordIDsToDeleteOnServer != nil || recordsToModifyOnServer != nil else {
            Log("SyncHandler - Nothing to delete or modify", module: .cloudSync)
            applyingChanges = false
            syncCompleted()
            return
        }
        Log("SyncHandler - Sending changes", module: .cloudSync)
        applyingChanges = true
        
        modifyQueue.setRecordsToModifyOnServer(recordsToModifyOnServer, deleteIDs: recordIDsToDeleteOnServer)
        let current = modifyQueue.currentBatch()
        cloudKit.modifyRecord(recordsToSave: current.modify, recordIDsToDelete: current.delete)
    }
    
    private func changesSavedSuccessfuly() {
        guard isSyncing, applyingChanges else { return }
        modifyQueue.prevBatchProcessed()
        if modifyQueue.finished {
            Log("SyncHandler - All Changes Saved Successfuly", module: .cloudSync)
            applyingChanges = false
            syncCompleted()
        } else {
            Log("SyncHandler - Batch Changes Saved Successfuly. Preparing next batch", module: .cloudSync)
            let current = modifyQueue.currentBatch()
            cloudKit.modifyRecord(recordsToSave: current.modify, recordIDsToDelete: current.delete)
        }
    }
    
    private func syncCompleted() {
        guard isSyncing else { return }
        Log("SyncHandler - Sync completed, clearing changes for sending", module: .cloudSync)
        isSyncing = false
        
        Log("SyncHandler - Sending current cloud state to local database", module: .cloudSync)
        let shouldRefreshLocalData = mergeHandler.applyChanges()
        
        finishedSync?()
        if shouldRefreshLocalData {
            refreshLocalData?()
        }
    }
    
    private func resetStack() {
        Log("SyncHandler - Sync Handler: resetStack", module: .cloudSync)
        applyingChanges = false
        modifyQueue.clear()
        mergeHandler.clear()
        cacheHandler.purge()
        ConstStorage.clearZone()
    }
    // swiftlint:enable line_length
}
