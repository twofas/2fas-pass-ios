// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

public final class CloudSync {
    private var cloudHandler: CloudHandler?
    private var syncHandler: SyncHandler?
    private var mergeHandler: MergeHandler?

    public var userToggledState: UserToggledState? {
        get {
            cloudHandler?.userToggledState
        }
        set {
            cloudHandler?.userToggledState = newValue
        }
    }
    public var currentState: CloudCurrentState { cloudHandler?.currentState ?? .unknown }
    public var isConnected: Bool { cloudHandler?.isConnected ?? false }

    public init() {}

    public func setup(
        localStorage: LocalStorage,
        cloudCacheStorage: CloudCacheStorage,
        encryptionHandler: EncryptionHandler,
        jsonDecoder: JSONDecoder,
        jsonEncoder: JSONEncoder,
        context: BackupSyncContext
    ) {
        guard cloudHandler == nil else { return }
        let cacheHandler = CacheHandler(cloudCacheStorage: cloudCacheStorage, jsonDecoder: jsonDecoder)
        let mergeHandler = MergeHandler(
            localStorage: localStorage,
            cloudCacheStorage: cloudCacheStorage,
            encryptionHandler: encryptionHandler,
            context: context,
            jsonDecoder: jsonDecoder,
            jsonEncoder: jsonEncoder
        )
        self.mergeHandler = mergeHandler
        let cloudKit = CloudKit()
        let cloudAvailability = CloudAvailability(container: cloudKit.container)
        let modifyQueue = ModificationBatchQueue()
        let syncHandler = SyncHandler(
            mergeHandler: mergeHandler,
            cacheHandler: cacheHandler,
            cloudKit: cloudKit,
            modifyQueue: modifyQueue
        )
        self.syncHandler = syncHandler
        cloudHandler = CloudHandler(
            cloudAvailability: cloudAvailability,
            syncHandler: syncHandler,
            mergeHandler: mergeHandler,
            cacheHandler: cacheHandler,
            context: context
        )
        checkForMigration(cloudCacheStorage: cloudCacheStorage)
    }

    public func setTakingOverVault(_ takingOver: Bool) {
        mergeHandler?.setTakingOverVault(takingOver)
    }

    public func synchronize(fromPush: Bool = false) {
        cloudHandler?.synchronize(fromPush: fromPush)
    }

    public func checkState() {
        cloudHandler?.checkState()
    }

    public func enable() {
        cloudHandler?.enable()
    }

    public func disable(notify: Bool) {
        cloudHandler?.disable(notify: notify)
    }

    public func clearBackup() {
        cloudHandler?.clearBackup()
    }

    public func setCurrentDate(_ date: Date) {
        syncHandler?.setCurrentDate(date)
    }

    @discardableResult
    func addStateChangedHandler(_ handler: @escaping (CloudCurrentState) -> Void) -> UUID? {
        cloudHandler?.addStateChangedHandler(handler)
    }

    func removeStateChangedHandler(_ id: UUID) {
        cloudHandler?.removeStateChangedHandler(id)
    }

    @discardableResult
    func addFinishedSyncHandler(_ handler: @escaping (Bool) -> Void) -> UUID? {
        cloudHandler?.addFinishedSyncHandler(handler)
    }

    func removeFinishedSyncHandler(_ id: UUID) {
        cloudHandler?.removeFinishedSyncHandler(id)
    }
}

private extension CloudSync {
    func checkForMigration(cloudCacheStorage: CloudCacheStorage) {
        if cloudCacheStorage.isInitializingNewStore {
            cloudHandler?.resetBeforeMigration()
            cloudCacheStorage.markInitializingNewStoreAsHandled()
        }
    }
}
