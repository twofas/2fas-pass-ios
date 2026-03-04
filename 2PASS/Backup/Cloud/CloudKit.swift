// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CloudKit
import Common

final class CloudKit {
    typealias DeletedEntries = ([(name: String, type: String)]) -> Void
    typealias UpdatedEntries = ([CKRecord]) -> Void
    typealias OtherError = (Error) -> Void
    
    private typealias ContinueOperation = () -> Void
    
    var deletedEntries: DeletedEntries?
    var updatedEntries: UpdatedEntries?
    var deleteAllEntries: Callback?
    
    var quotaExceeded: Callback?
    var userDisablediCloud: Callback?
    var useriCloudProblem: Callback?
    var userLoggedOut: Callback?
    var resetStack: Callback?
    
    var fetchFinishedSuccessfuly: Callback?
    var changesSavedSuccessfuly: Callback?
    
    private var zoneID: CKRecordZone.ID!
    
    private let containerIdentifier = Config.containerIdentifier
    private let notificationIdentifier = "TwoPassVault"
    private let errorParser = CloudKitErrorParser()
    
    private weak var operation: Operation?
    
    private var database: CKDatabase!
    private(set) var container: CKContainer!
    
    private var zoneUpdated = false
    private var changedRecords: [CKRecord] = []
    private var deletedRecords: [DeletedItem] = []
    
    private var collectedActions: [CloudKitAction] = []
    
    private let syncTokenHandler = SyncTokenHandler()
    
    init() {
        container = CKContainer(identifier: containerIdentifier)
        database = container.privateCloudDatabase
    }
    
    func cloudSync(zoneID: CKRecordZone.ID) {
        Log("CloudKit - cloudSync()", module: .cloudSync)
        self.zoneID = zoneID
        collectedActions = []

        DispatchQueue.global(qos: .utility).async {
            self.syncTokenHandler.prepare()
            
            self.creatingCustomZone { [weak self] in
                self?.subscribeToChanges { [weak self] in
                    self?.fetchDatabaseChanges { [weak self] in
                        self?.fetchZoneChanges()
                    }
                }
            }
        }
    }
    
    private func creatingCustomZone(continueOperation: @escaping ContinueOperation) {
        Log("CloudKit - entering zone creation", module: .cloudSync)
        guard !ConstStorage.zoneInitiated else {
            Log("CloudKit - zone initiated", module: .cloudSync)
            continueOperation()
            return
        }
        Log("CloudKit - creating zone", module: .cloudSync)
        
        let zone = CKRecordZone(zoneID: zoneID)
        let operation = CKModifyRecordZonesOperation(recordZonesToSave: [zone], recordZoneIDsToDelete: [])
        
        operation.perRecordZoneSaveBlock = { [weak self] _, result in
            Log("CloudKit - perRecordZoneSaveBlock", module: .cloudSync)
            switch result {
            case .success(let savedRecordZone):
                if savedRecordZone == zone {
                    Log("CloudKit - perRecordZoneSaveBlock - zone initiated", module: .cloudSync)
                    self?.syncTokenHandler.setZoneInitiated()
                } else {
                    Log("CloudKit - perRecordZoneSaveBlock - no zone, purging cache!", module: .cloudSync)
                    self?.resetCache { [weak self] in
                        self?.retryAction()
                    }
                }
            case .failure(let error):
                self?.savePartialOperationError(error)
                Log("CloudKit - perRecordZoneSaveBlock - handling error: \(error)", module: .cloudSync)
            }
        }
        
        operation.modifyRecordZonesResultBlock = { [weak self] result in
            Log("CloudKit - modifyRecordZonesResultBlock", module: .cloudSync)
            switch result {
            case .success:
                Log("CloudKit - modifyRecordZonesResultBlock - success", module: .cloudSync)
                self?.handleOperationResult(error: nil) {
                    continueOperation()
                }
            case .failure(let error):
                Log("CloudKit - modifyRecordZonesResultBlock - handling error: \(error)", module: .cloudSync)
                self?.handleOperationResult(error: error)
            }
        }

        addOperationToDatabase(operation)
    }
    
    // also save to disk, guard and check on start if already done
    private func subscribeToChanges(continueOperation: @escaping ContinueOperation) {
        Log("CloudKit - subscribeToChanges - entering", module: .cloudSync)
        guard !ConstStorage.notificationsInitiated else {
            Log("CloudKit - already subscribed. Continuing", module: .cloudSync)
            continueOperation();
            return
        }
        Log("CloudKit - Subscribing to changes", module: .cloudSync)
        
        let subscription = CKRecordZoneSubscription(zoneID: zoneID, subscriptionID: notificationIdentifier)
        let notificationInfo = CKSubscription.NotificationInfo()
        notificationInfo.shouldSendContentAvailable = true
        subscription.notificationInfo = notificationInfo
                
        let operation = CKModifySubscriptionsOperation(
            subscriptionsToSave: [subscription],
            subscriptionIDsToDelete: nil
        )
        
        operation.perSubscriptionSaveBlock = { [weak self] _, result in
            switch result {
            case .success(let savedSubscription):
                Log("CloudKit - perSubscriptionSaveBlock - no error", module: .cloudSync)
                if savedSubscription == subscription {
                    Log("CloudKit - perSubscriptionSaveBlock - success", module: .cloudSync)
                    self?.syncTokenHandler.setNotificationsInitiated()
                }
                Log("CloudKit - perSubscriptionSaveBlock - Can't subscribe but there's no error", module: .cloudSync)
            case .failure(let error):
                self?.savePartialOperationError(error)
                Log("CloudKit - perSubscriptionSaveBlock - error: \(error)", module: .cloudSync)
            }
        }
        
        operation.modifySubscriptionsResultBlock = { [weak self] result in
            Log("CloudKit - modifySubscriptionsResultBlock", module: .cloudSync)
            switch result {
            case .success:
                Log("CloudKit - modifySubscriptionsResultBlock - success", module: .cloudSync)
                self?.handleOperationResult(error: nil) {
                    continueOperation()
                }
            case .failure(let error):
                Log("CloudKit - modifySubscriptionsResultBlock - error: \(error)", module: .cloudSync)
                self?.handleOperationResult(error: error)
            }
        }
        
        addOperationToDatabase(operation)
    }
    
    private func fetchDatabaseChanges(continueOperation: @escaping ContinueOperation) {
        // swiftlint:disable line_length
        Log("CloudKit - Fetching Server Notifications, token is set: \(ConstStorage.databaseChangeToken != nil)", module: .cloudSync)
        // swiftlint:enable line_length
        let operation = CKFetchDatabaseChangesOperation(previousServerChangeToken: ConstStorage.databaseChangeToken)
        operation.fetchAllChanges = true
        operation.recordZoneWithIDChangedBlock = { [weak self] recordZoneId in
            self?.zoneChanged(with: recordZoneId)
        }
        operation.recordZoneWithIDWasPurgedBlock = { [weak self] recordZoneId in
            self?.zoneWasPurged(with: recordZoneId)
        }
        operation.recordZoneWithIDWasDeletedBlock = { [weak self] recordZoneId in
            self?.zoneWasDeleted(with: recordZoneId)
        }
        operation.fetchDatabaseChangesResultBlock = { [weak self] result in
            Log("CloudKit - fetchDatabaseChangesResultBlock", module: .cloudSync)
            switch result {
            case .success((let serverChangeToken, _ )):
                Log("CloudKit - fetchDatabaseChangesResultBlock - obtained new database token", module: .cloudSync)
                self?.syncTokenHandler.setDatabaseChangeToken(serverChangeToken)
                continueOperation()
            case .failure(let error):
                Log("CloudKit - fetchDatabaseChangesResultBlock - error \(error)", module: .cloudSync)
                self?.handleOperationResult(error: error)
            }
        }
        
        addOperationToDatabase(operation)
    }
    
    private func fetchZoneChanges() {
        guard zoneUpdated else {
            Log("CloudKit - NO zone changes - exiting", module: .cloudSync)
            DispatchQueue.main.async {
                self.syncTokenHandler.commitChanges()
                self.fetchFinishedSuccessfuly?()
            }
            return
        }
        
        Log("CloudKit - clearing record changes", module: .cloudSync)
        clearRecordChanges()
        
        Log(
            "CloudKit - fetching zone changes, token is set: \(ConstStorage.zoneChangeToken != nil)",
            module: .cloudSync
        )
        
        let operation = CKFetchRecordZoneChangesOperation(
            recordZoneIDs: [zoneID],
            configurationsByRecordZoneID: [
                zoneID: CKFetchRecordZoneChangesOperation.ZoneConfiguration(
                    previousServerChangeToken: ConstStorage.zoneChangeToken,
                    resultsLimit: nil,
                    desiredKeys: nil
                )
            ]
        )
        operation.fetchAllChanges = true
        operation.recordWasChangedBlock = { [weak self] recordID, result in
            Log("CloudKit - recordWasChangedBlock - recordID: \(recordID)", module: .cloudSync, save: false)
            switch result {
            case .success(let record):
                Log("CloudKit - recordWasChangedBlock - success", module: .cloudSync)
                self?.recordChanged(record)
            case .failure(let error):
                self?.savePartialOperationError(error)
                Log("CloudKit - recordWasChangedBlock - errror: \(error)", module: .cloudSync)
            }
        }
        operation.recordWithIDWasDeletedBlock = { [weak self] deletedRecordId, deletedRecordType in
            self?.recordDeleted(deletedRecordId, of: deletedRecordType)
        }
        operation.recordZoneChangeTokensUpdatedBlock = { [weak self] _, recordZoneToken, _ in
            self?.recordZoneTokenUpdated(recordZoneToken)
        }
        operation.recordZoneFetchResultBlock = { [weak self] _, result in
            switch result {
            case .success((let serverChangeToken, _, _)):
                Log("CloudKit - recordZoneFetchResultBlock - success", module: .cloudSync)
                self?.handleOperationResult(error: nil) { [weak self] in
                    self?.recordZoneTokenUpdated(serverChangeToken)
                }
            case .failure(let error):
                Log("CloudKit - recordZoneFetchResultBlock - error: \(error)", module: .cloudSync)
                self?.handleOperationResult(error: error)
            }
        }
        operation.fetchRecordZoneChangesResultBlock = { [weak self] result in
            switch result {
            case .success:
                Log("CloudKit - fetchRecordZoneChangesResultBlock - success", module: .cloudSync)
                self?.handleOperationResult(error: nil) { [weak self] in
                    self?.finishedFetchingZoneChange()
                }
            case .failure(let error):
                Log("CloudKit - fetchRecordZoneChangesResultBlock - error: \(error)", module: .cloudSync)
                self?.handleOperationResult(error: error)
            }
        }

        addOperationToDatabase(operation)
    }
    
    func modifyRecord(recordsToSave: [CKRecord]?, recordIDsToDelete: [CKRecord.ID]?) {
        Log(
            "CloudKit - modifyRecord \(recordsToSave?.count ?? 0), \(recordIDsToDelete?.count ?? 0)",
            module: .cloudSync
        )
        let operation = CKModifyRecordsOperation(recordsToSave: recordsToSave, recordIDsToDelete: recordIDsToDelete)
        operation.isAtomic = true
        operation.savePolicy = .ifServerRecordUnchanged
        
        operation.perRecordDeleteBlock = { [weak self] recordID, result in
            Log("CloudKit - perRecordDeleteBlock", module: .cloudSync)
            switch result {
            case .success:
                Log("CloudKit - perRecordDeleteBlock - success", module: .cloudSync)
                Log("CloudKit - perRecordDeleteBlock - recordID: \(recordID)", module: .cloudSync, save: false)
            case .failure(let error):
                self?.savePartialOperationError(error)
                Log("CloudKit - perRecordDeleteBlock - error: \(error)", module: .cloudSync)
            }
        }
        operation.perRecordSaveBlock = { [weak self] recordID, result in
            Log("CloudKit - perRecordSaveBlock", module: .cloudSync)
            switch result {
            case .success(let record):
                Log("CloudKit - perRecordSaveBlock - success", module: .cloudSync)
                Log(
                    "CloudKit - perRecordSaveBlock - recordID: \(recordID),\n\nrecord: \(record)",
                    module: .cloudSync,
                    save: false
                )
            case .failure(let error):
                self?.savePartialOperationError(error)
                Log(
                    "CloudKit - perRecordSaveBlock - error: \(error), \((error as NSError).userInfo)",
                    module: .cloudSync
                )
            }
        }
        operation.modifyRecordsResultBlock = { [weak self] result in
            Log("CloudKit - modifyRecordsResultBlock", module: .cloudSync)
            switch result {
            case .success:
                Log("CloudKit - modifyRecordsResultBlock - success", module: .cloudSync)
                self?.handleOperationResult(error: nil) { [weak self] in
                    self?.changesSaved()
                }
            case .failure(let error):
                Log("CloudKit - modifyRecordsResultBlock - error: \(error)", module: .cloudSync)
                self?.handleOperationResult(error: error)
            }
        }

        addOperationToDatabase(operation)
    }
    
    func clear() {
        Log("CloudKit - clear", module: .cloudSync)
        syncTokenHandler.prepare()
        clearRecordChanges()
        collectedActions = []
        operation?.cancel()
        operation = nil
    }
    
    // MARK: - ZONE
    
    private func zoneChanged(with zoneID: CKRecordZone.ID) {
        Log("CloudKit - Zone changed with ID: \(zoneID)", module: .cloudSync)
        
        if self.zoneID == zoneID {
            Log("CloudKit - zoneUpdated = true", module: .cloudSync)
            zoneUpdated = true
        }
    }
    
    private func zoneWasPurged(with zoneID: CKRecordZone.ID) {
        Log("CloudKit - Zone purged with ID: \(zoneID)", module: .cloudSync)
        
        if self.zoneID == zoneID {
            Log("CloudKit - zoneID == zoneID -> resetStack", module: .cloudSync)
            resetCache()
        }
    }
    
    private func zoneWasDeleted(with zoneID: CKRecordZone.ID) {
        Log("CloudKit - Zone DELETED with ID: \(zoneID)", module: .cloudSync)
        
        if self.zoneID == zoneID {
            Log("CloudKit - zoneID == zoneID -> purgeCache", module: .cloudSync)
            DispatchQueue.main.async {
                self.userDisablediCloud?()
            }
        }
    }
    
    private func addOperationToDatabase(_ operation: CKDatabaseOperation) {
        operation.queuePriority = .veryHigh
        operation.qualityOfService = .userInitiated
        
        database.add(operation)
        self.operation = operation
    }
    
    // MARK: - Error handling
    
    private func savePartialOperationError(_ error: Error) {
        Log("CloudKit - partialOperationError: \(error)", module: .cloudSync)
        if let action = errorParser.handle(error: error as NSError) {
            collectedActions.append(action)
        }
    }
    
    private func handleOperationResult(error: Error?, next: Callback? = nil) {
        Log("CloudKit - handleOperationResult: \(String(describing: error))", module: .cloudSync)
        if error == nil && collectedActions.isEmpty {
            next?()
            return
        }
        if let error, let action = errorParser.handle(error: error as NSError) {
            collectedActions.append(action)
        }
        guard let mostImportant = collectedActions.sortedByImportance.last else {
            collectedActions = []
            next?()
            return
        }
        switch mostImportant {
        case .retry(let after): retryAction(after)
        case .resetAndRetry(let after):
            resetCache { [weak self] in
                self?.retryAction(after)
            }
        case .stop(let reason):
            resetCache()
            DispatchQueue.main.async {
                switch reason {
                case .userDisablediCloud:
                    self.userDisablediCloud?()
                case .iCloudProblem:
                    self.useriCloudProblem?()
                case .quotaExceeded:
                    self.quotaExceeded?()
                case .notLoggedIn:
                    self.userLoggedOut?()
                }
            }
        }
        collectedActions = []
    }
    
    // MARK: - RECORDS
    
    private func clearRecordChanges() {
        Log("CloudKit - clearRecordChanges", module: .cloudSync)
        changedRecords = []
        deletedRecords = []
    }
    
    private func recordChanged(_ changedRecord: CKRecord) {
        Log("CloudKit - Appending changed record of type: \(changedRecord.recordType)", module: .cloudSync)
        Log("Record: \(changedRecord)", module: .cloudSync, save: false)
        changedRecords.append(changedRecord)
    }
    
    private func recordDeleted(_ deletedRecord: CKRecord.ID, of type: CKRecord.RecordType) {
        Log("CloudKit - Appending deleted record of type: \(type)", module: .cloudSync)
        Log("Record: \(deletedRecord)", module: .cloudSync, save: false)
        let record = DeletedItem(record: deletedRecord, type: type)
        deletedRecords.append(record)
    }
    
    private func recordZoneTokenUpdated(_ token: CKServerChangeToken?) {
        guard let token else {
            Log("CloudKit - New token for zone should be received but there was none!", module: .cloudSync)
            return
        }
        Log("CloudKit - New token for zone received", module: .cloudSync)
        syncTokenHandler.setZoneChangeToken(token)
    }
    
    private func finishedFetchingZoneChange() {
        Log("CloudKit - finishedFetchingZoneChange", module: .cloudSync)
        zoneUpdated = false
        
        DispatchQueue.main.async {
            if !self.deletedRecords.isEmpty {
                Log("CloudKit - deletedRecords not empty", module: .cloudSync)
                self.deletedEntries?(self.deletedRecords.map { (name: $0.record.recordName, type: $0.type) })
            }
            
            if !self.changedRecords.isEmpty {
                Log("CloudKit - changedRecords not empty", module: .cloudSync)
                self.updatedEntries?(self.changedRecords)
            }
            
            self.clearRecordChanges()
            
            self.syncTokenHandler.commitChanges()
            self.fetchFinishedSuccessfuly?()
        }
    }
    
    private func changesSaved() {
        Log("CloudKit - Changes were saved successfully", module: .cloudSync)
        DispatchQueue.main.async {
            self.changesSavedSuccessfuly?()
        }
    }
    
    private func resetCache(cacheReseted: Callback? = nil) {
        Log("CloudKit - Deleting cache", module: .cloudSync)
        Log("CloudKit - Deleting all entries in sync cache", module: .cloudSync)
        syncTokenHandler.clearZone()
        clearRecordChanges()
        DispatchQueue.main.async {
            self.resetStack?()
            cacheReseted?()
        }
    }
    
    private func retryAction(_ retryIn: TimeInterval = 2.0) {
        Log("CloudKit - Preparing to retry sync in \(retryIn)", module: .cloudSync)
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + retryIn) {
            Log("CloudKit - Scheduled sync -> syncing", module: .cloudSync)
            self.cloudSync(zoneID: self.zoneID)
        }
    }
}

private struct DeletedItem {
    let record: CKRecord.ID
    let type: CKRecord.RecordType
}
