// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CommonUI
import Common
import Data
import Backup
import UIKit

enum SyncDestination: RouterDestination {
    case webDAV
    case disableWebDAVConfirmation(onConfirm: Callback)
    case iCloudNotAvailable(reason: String?)
    case iCloudSchemeNotSupported(Int, onUpdateApp: Callback)
    case syncNotAllowed
    
    var id: String {
        switch self {
        case .webDAV:
            "WebDAV"
        case .iCloudSchemeNotSupported:
            "iCloudSchemeNotSupported"
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
                 if interactor.isWebDAVEnabled {
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
        isWebDAVEnabled ? String(localized: .commonEnabled) : String(localized: .commonDisabled)
    }
    
    private(set) var status: String?
    private(set) var lastSyncDate: Date?
    private(set) var isWebDAVEnabled: Bool
    private(set) var showUpgradePlanButton: Bool = false
    private(set) var showUpdateAppButton: Bool = false
    
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
    
    func onWebDAV() {
        destination = .webDAV
    }
    
    func onUpdateApp() {
        UIApplication.shared.open(Config.appStoreURL)
    }
    
    private func refreshStatus() {
        icloudSyncEnabled = interactor.isCloudEnabled
        
        if interactor.isCloudEnabled {
            status = interactor.cloudState.description
            lastSyncDate = interactor.cloudLastSuccessSyncDate
            showUpdateAppButton = interactor.cloudState.isSchemeNotSupported
        } else if interactor.isWebDAVEnabled {
            status = WebDAVStatusFormatStyle().format(interactor.webDAVState)
            lastSyncDate = interactor.webDAVLastSyncDate
            showUpgradePlanButton = interactor.webDAVState.isLimitDevicesReached
            showUpdateAppButton = interactor.webDAVState.isSchemeNotSupported
        } else {
            showUpdateAppButton = false
            
            switch interactor.cloudState {
            case .enabledNotAvailable(.schemaNotSupported(let schemaVersion)):
                destination = .iCloudSchemeNotSupported(schemaVersion, onUpdateApp: { [weak self] in
                    self?.onUpdateApp()
                })
            case .enabledNotAvailable(let reason):
                destination = .iCloudNotAvailable(reason: reason.description)
            default:
                break
            }
            
            status = nil
            lastSyncDate = nil
        }
        
        isWebDAVEnabled = interactor.isWebDAVEnabled
    }
    
    @MainActor
    private func onPresentPremium() {
        destination = .syncNotAllowed
    }
}

struct WebDAVStatusFormatStyle: FormatStyle {
    
    func format(_ value: WebDAVState) -> String {
        switch value {
        case .synced: String(localized: .syncStatusSynced)
        case .syncing: String(localized: .syncStatusSyncing)
        case .idle: String(localized: .syncStatusIdle)
        case .error(let error):
            switch error {
            case .forbidden: String(localized: .syncStatusErrorForbidden)
            case .methodNotAllowed: String(localized: .syncStatusErrorMethodNotAllowed)
            case .networkError(let networkError): networkError
            case .notConfigured: String(localized: .syncStatusErrorNotConfigured)
            case .limitDevicesReached: String(localized: .syncStatusErrorLimitDevicesReached)
            case .serverError(let serverError): serverError
            case .sslError: String(localized: .syncStatusErrorSslError)
            case .syncError(let syncError): syncError ?? error.localizedDescription
            case .unauthorized: String(localized: .syncStatusErrorUnauthorized)
            case .urlError(let urlError): urlError
            case .passwordChanged: String(localized: .syncStatusErrorPasswordChanged)
            case .schemaNotSupported(let schemaVersion): String(localized: .cloudSyncInvalidSchemaErrorMsg(Int32(schemaVersion)))
            }
        case .retry(let reason):
            reason.map { "\(String(localized: .syncStatusRetry)) \($0)" } ?? String(localized: .syncStatusRetry)
            
        }
    }
}

private extension CloudState.Sync {
    var description: String {
        switch self {
        case .syncing: String(localized: .syncSyncing)
        case .synced: String(localized: .syncSynced)
        case .outOfSync(.schemaNotSupported(let schemaVersion)): String(localized: .cloudSyncInvalidSchemaErrorMsg(Int32(schemaVersion)))
        }
    }
}

private extension CloudState {
    var description: String {
        switch self {
        case .unknown: String(localized: .syncChecking)
        case .enabledNotAvailable(let reason): String(localized: .syncNotAvailable) + "\n" + reason.description
        case .disabled: String(localized: .syncDisabled)
        case .enabled(let sync): sync.description
        }
    }
}

private extension CloudState.NotAvailableReason {
    var description: String {
        switch self {
        case .overQuota: String(localized: .syncErrorIcloudQuota)
        case .disabledByUser: String(localized: .syncErrorIcloudDisabled)
        case .error(let error):
            if let error {
                if let error = error as? MergeHandlerError, let description = error.description {
                    String(localized: .syncErrorIcloudErrorDetails(description))
                } else {
                    String(localized: .syncErrorIcloudErrorDetails(error.localizedDescription))
                }
            } else {
                String(localized: .syncErrorIcloudError)
            }
        case .useriCloudProblem: String(localized: .syncErrorIcloudErrorUserLoggedIn)
        case .other: String(localized: .syncErrorIcloudErrorReboot)
        case .schemaNotSupported(let schemaVersion): String(localized: .cloudSyncInvalidSchemaErrorMsg(Int32(schemaVersion)))
        case .incorrectEncryption: String(localized: .syncErrorIcloudErrorDiffrentEncryption)
        case .noAccount: String(localized: .syncErrorIcloudErrorNoAccount)
        case .restricted: String(localized: .syncErrorIcloudErrorAccessRestricted)
        }
    }
}

private extension MergeHandlerError {
    var description: String? {
        switch self {
        case .schemaNotSupported: String(localized: .syncErrorIcloudErrorNewerVersion)
        case .noLocalVault: String(localized: .generalErrorNoLocalVault)
        case .incorrectEncryption: String(localized: .syncErrorIcloudVaultEncryptionRestore)
        case .mergeError: String(localized: .syncErrorIcloudMergeError)
        case .syncNotAllowed: String(localized: .syncErrorIcloudSyncNotAllowedDescription)
        case .missingEncryption: nil
        }
    }
}
