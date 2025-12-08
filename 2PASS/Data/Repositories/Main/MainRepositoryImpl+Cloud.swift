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
    
    func cloudDeleteVault(id: VaultID) async throws {
        try await cloudRecovery.deleteVault(id: id)
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
        case .enabledNotAvailable(let reason):
            switch reason {
            case .overQuota:
                return .enabledNotAvailable(reason: .overQuota)
            case .disabledByUser:
                return .enabledNotAvailable(reason: .disabledByUser)
            case .error(let error):
                return .enabledNotAvailable(reason: .error(error: error))
            case .useriCloudProblem:
                return .enabledNotAvailable(reason: .useriCloudProblem)
            case .other:
                return .enabledNotAvailable(reason: .other)
            case .schemaNotSupported(let schemaVersion):
                return .enabledNotAvailable(reason: .schemaNotSupported(schemaVersion))
            case .incorrectEncryption:
                return .enabledNotAvailable(reason: .incorrectEncryption)
            case .noAccount:
                return .enabledNotAvailable(reason: .noAccount)
            case .restricted:
                return .enabledNotAvailable(reason: .restricted)
            }
        case .disabled:
            return .disabled
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
