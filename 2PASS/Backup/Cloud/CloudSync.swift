// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

public enum CloudCurrentState: Equatable {
    public enum NotAvailableReason: Equatable {
        case overQuota
        case disabledByUser
        case useriCloudProblem
        case error(error: NSError?)
        case other
        case noAccount
        case restricted
        case newerVersion
        case incorrectEncryption
    }
    
    public enum Sync: Equatable {
        case syncing // in progress
        case synced // all done
        // case error(error: NSError) <- not used. Sync restarts itself
    }
    
    case unknown
    case disabledNotAvailable(reason: NotAvailableReason)
    case disabledAvailable
    case enabled(sync: Sync)
}

public typealias UserToggledState = (Bool) -> Void


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
        deviceID: DeviceID,
        jsonDecoder: JSONDecoder,
        jsonEncoder: JSONEncoder
    ) {
        guard cloudHandler == nil else { return }
        let cacheHandler = CacheHandler(cloudCacheStorage: cloudCacheStorage, jsonDecoder: jsonDecoder)
        let mergeHandler = MergeHandler(
            localStorage: localStorage,
            cloudCacheStorage: cloudCacheStorage,
            encryptionHandler: encryptionHandler,
            deviceID: deviceID,
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
            cacheHandler: cacheHandler
        )
    }
    
    public func setMultiDeviceSyncEnabled(_ enabled: Bool) {
        mergeHandler?.setMultiDeviceSyncEnabled(enabled)
    }
    
    public func setVaultID(_ vaultID: VaultID) {
        cloudHandler?.setVaultID(vaultID: vaultID)
    }
    
    public func synchronize() {
        cloudHandler?.synchronize()
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
}
