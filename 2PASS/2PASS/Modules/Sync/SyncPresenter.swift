// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CommonUI
import Common
import Data
import Backup

enum SyncDestination: RouterDestination {
    case webDAV
    case disableWebDAVConfirmation(onConfirm: Callback)
    case iCloudNotAvailable(reason: String?)
    case syncNotAllowed
    
    var id: String {
        switch self {
        case .webDAV:
            "WebDAV"
        case .disableWebDAVConfirmation:
            "DisableWebDAVConfirmation"
        case .iCloudNotAvailable:
            "iCloudNotAvailable"
        case .syncNotAllowed:
            "syncNotAllowed"
        }
    }
}

@Observable @MainActor
final class SyncPresenter {
    
    var destination: SyncDestination?
    
    var icloudSyncEnabled: Bool {
        get {
            interactor.isCloudEnabled
        }
        set {
            guard newValue != interactor.isCloudEnabled else {
                return
            }
            
            if newValue {
                if case .disabledNotAvailable(reason: let reason) = interactor.cloudState {
                    destination = .iCloudNotAvailable(reason: reason.description)
                } else if newValue, interactor.isWebDAVEnabled {
                    destination = .disableWebDAVConfirmation(onConfirm: { [interactor] in
                        interactor.disableWebDAV()
                        interactor.turnOnCloud()
                    })
                } else {
                    interactor.turnOnCloud()
                }
            } else {
                interactor.turnOffCloud()
            }
        }
    }
    
    var webDAVEnableStatus: String {
        isWebDAVEnabled ? T.commonEnabled : T.commonDisabled
    }
    
    private(set) var status: String?
    private(set) var lastSyncDate: Date?
    private(set) var isWebDAVEnabled: Bool
    private(set) var showUpgradePlanButton: Bool = false
    
    private var presentSyncPremiumNeededScreen: Task<Void, Never>?
    
    private let interactor: SyncModuleInteracting
    
    init(interactor: SyncModuleInteracting) {
        self.interactor = interactor
        self.isWebDAVEnabled = interactor.isWebDAVEnabled
        
        refreshStatus()
        
        interactor.cloudStateChanged = { [weak self] in
            Task { @MainActor in
                self?.refreshStatus()
            }
        }
        
        interactor.webDAVStateChanged = { [weak self] in
            Task { @MainActor in
                self?.refreshStatus()
            }
        }
        
        presentSyncPremiumNeededScreen = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: .presentSyncPremiumNeededScreen)
                .compactMap({ _ in }) {
                self?.onPresentPremium()
            }
        }
    }
    
    func onAppear() {
        refreshStatus()
    }
    
    func onUpgradePlan() {
        NotificationCenter.default.post(name: .presentPaymentScreen, object: nil)
    }
    
    private func refreshStatus() {
        icloudSyncEnabled = interactor.isCloudEnabled
        
        if interactor.isCloudEnabled {
            status = interactor.cloudState.description
            lastSyncDate = interactor.cloudLastSuccessSyncDate
        } else if interactor.isWebDAVEnabled {
            status = WebDAVStatusFormatStyle().format(interactor.webDAVState)
            lastSyncDate = interactor.webDAVLastSyncDate
            showUpgradePlanButton = interactor.webDAVState.isLimitDevicesReached
        } else {
            status = nil
            lastSyncDate = nil
        }
        
        isWebDAVEnabled = interactor.isWebDAVEnabled
    }
    
    func onWebDAV() {
        destination = .webDAV
    }
    
    @MainActor
    private func onPresentPremium() {
        destination = .syncNotAllowed
    }
}

struct WebDAVStatusFormatStyle: FormatStyle {
    
    func format(_ value: WebDAVState) -> String {
        switch value {
        case .synced: T.syncStatusSynced
        case .syncing: T.syncStatusSyncing
        case .idle: T.syncStatusIdle
        case .error(let error):
            switch error {
            case .forbidden: T.syncStatusErrorForbidden
            case .methodNotAllowed: T.syncStatusErrorMethodNotAllowed
            case .networkError(let networkError): networkError
            case .newerVersionNeeded: T.syncStatusErrorNewerVersionNeededTitle
            case .notConfigured: T.syncStatusErrorNotConfigured
            case .limitDevicesReached: T.syncStatusErrorLimitDevicesReached
            case .serverError(let serverError): serverError
            case .sslError: T.syncStatusErrorSslError
            case .syncError(let syncError): syncError ?? error.localizedDescription
            case .unauthorized: T.syncStatusErrorUnauthorized
            case .urlError(let urlError): urlError
            case .passwordChanged: T.syncStatusErrorPasswordChanged
            }
        case .retry(let reason):
            reason.map { "\(T.syncStatusRetry) \($0)" } ?? T.syncStatusRetry
            
        }
    }
}

private extension CloudState.Sync {
    var description: String {
        switch self {
        case .syncing: T.syncSyncing
        case .synced: T.syncSynced
        }
    }
}

private extension CloudState {
    var description: String {
        switch self {
        case .unknown: T.syncChecking
        case .disabledNotAvailable: T.syncNotAvailable
        case .disabledAvailable: T.syncDisabled
        case .enabled(let sync): sync.description
        }
    }
}

private extension CloudState.NotAvailableReason {
    var description: String {
        switch self {
        case .overQuota: T.syncErrorIcloudQuota
        case .disabledByUser: T.syncErrorIcloudDisabled
        case .error(let error):
            if let error {
                if let error = error as? MergeHandlerError {
                    T.syncErrorIcloudErrorDetails(error.description)
                } else {
                    T.syncErrorIcloudErrorDetails(error)
                }
            } else {
                T.syncErrorIcloudError
            }
        case .useriCloudProblem: T.syncErrorIcloudErrorUserLoggedIn
        case .other: T.syncErrorIcloudErrorReboot
        case .newerVersion: T.syncErrorIcloudErrorNewerVersion
        case .incorrectEncryption: T.syncErrorIcloudErrorDiffrentEncryption
        case .noAccount: T.syncErrorIcloudErrorNoAccount
        case .restricted: T.syncErrorIcloudErrorAccessRestricted
        }
    }
}

private extension MergeHandlerError {
    var description: String {
        switch self {
        case .newerVersion: T.syncErrorIcloudErrorNewerVersion
        case .noLocalVault: T.generalErrorNoLocalVault
        case .incorrectEncryption: T.syncErrorIcloudVaultEncryptionRestore
        case .mergeError: T.syncErrorIcloudMergeError
        case .syncNotAllowed: T.syncErrorIcloudSyncNotAllowedDescription
        }
    }
}
