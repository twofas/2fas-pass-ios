// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Backup
import Common

extension MainRepositoryImpl {
    var isCloudBackupConnected: Bool {
        cloudSync.isConnected
    }
    
    var cloudCurrentState: CloudState {
        cloudCurrentStateToCloudState(cloudSync.currentState)
    }
        
    func enableCloudBackup() {
        cloudSync.enable()
    }
    
    func disableCloudBackup() {
        cloudSync.disable(notify: true)
        clearLastSuccessCloudSyncDate()
    }
    
    func clearBackup() {
        cloudSync.clearBackup()
    }
    
    func synchronizeBackup() {
        cloudSync.synchronize()
    }
    
    func cloudListVaultsToRecover(completion: @escaping (Result<[VaultRawData], Error>) -> Void) {
        cloudRecovery.listVaultsToRecover(completion: completion)
    }
    
    var lastSuccessCloudSyncDate: Date? {
        userDefaultsDataSource.lastSuccessCloudSyncDate
    }
    
    func setLastSuccessCloudSyncDate(_ date: Date) {
        userDefaultsDataSource.setLastSuccessCloudSyncDate(date)
    }
    
    func clearLastSuccessCloudSyncDate() {
        userDefaultsDataSource.clearLastSuccessCloudSyncDate()
    }
}

private extension MainRepositoryImpl {
    func cloudCurrentStateToCloudState(_ cloudCurrentState: CloudCurrentState) -> CloudState {
        switch cloudCurrentState {
        case .unknown:
            return .unknown
        case .disabledNotAvailable(let reason):
            switch reason {
            case .overQuota:
                return .disabledNotAvailable(reason: .overQuota)
            case .disabledByUser:
                return .disabledNotAvailable(reason: .disabledByUser)
            case .error(let error):
                return .disabledNotAvailable(reason: .error(error: error))
            case .useriCloudProblem:
                return .disabledNotAvailable(reason: .useriCloudProblem)
            case .other:
                return .disabledNotAvailable(reason: .other)
            case .newerVersion:
                return .disabledNotAvailable(reason: .newerVersion)
            case .incorrectEncryption:
                return .disabledNotAvailable(reason: .incorrectEncryption)
            case .noAccount:
                return .disabledNotAvailable(reason: .noAccount)
            case .restricted:
                return .disabledNotAvailable(reason: .restricted)
            }
        case .disabledAvailable:
            return .disabledAvailable
        case .enabled(let sync):
            switch sync {
            case .syncing:
                return .enabled(sync: .syncing)
            case .synced:
                return .enabled(sync: .synced)
            }
        }
    }
}
