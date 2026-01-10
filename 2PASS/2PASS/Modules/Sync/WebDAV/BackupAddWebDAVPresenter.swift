// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common

enum BackupAddWebDAVRouteDestination: RouterDestination {
    case disableCloudSyncConfirmation(onConfirm: Callback)
    case upgradePlanPrompt
    
    var id: String {
        switch self {
        case .disableCloudSyncConfirmation:
            "DiableCloudSyncConfirmation"
        case .upgradePlanPrompt:
            "UpgradePlanPrompt"
        }
    }
}

@Observable
final class BackupAddWebDAVPresenter {
    
    var destination: BackupAddWebDAVRouteDestination?
    
    var url: String = ""
    var allowTLSOff = false
    var username: String = ""
    var password: String = ""
    
    var uriError: String? = nil
    var isLoading = false
    var isConnected = false
    var isEditable = true
    
    private let interactor: BackupAddWebDAVModuleInteracting
    
    init(interactor: BackupAddWebDAVModuleInteracting) {
        self.interactor = interactor

        interactor.statusChanged = { [weak self] status in
            self?.showStatus(status)
        }
    }
}

extension BackupAddWebDAVPresenter {
    func onAppear() {
        guard let config = interactor.savedConfiguration else {
            return
        }
        isConnected = interactor.isConnected
        isLoading = interactor.isConnecting
        isEditable = !interactor.isConnected
        allowTLSOff = config.allowTLSOff
        url = config.baseURL
        username = config.login ?? ""
        password = config.password ?? ""
    }
    
    func onDisappear() {
        guard !interactor.isConnected else {
            return
        }
        interactor.disconnect()
    }
    
    func onConnect() {
        guard let normalizedURL = interactor.normalizeURL(url) else {
            uriError = String(localized: .syncStatusErrorWrongDirectoryUrl)
            isLoading = false
            isEditable = true
            return
        }
        
        guard interactor.isSecureURL(normalizedURL) else {
            uriError = "Unsecure URL!"
            isLoading = false
            isEditable = true
            return
        }
        
        guard interactor.isSyncCloudEnabled == false else {
            destination = .disableCloudSyncConfirmation(onConfirm: { [weak self, url] in
                self?.interactor.disableSyncCloud()
                self?.connect(to: url, normalizedURL: normalizedURL)
            })
            return
        }
        connect(to: url, normalizedURL: normalizedURL)
    }
    
    func onDisconnect() {
        interactor.disconnect()
        isConnected = false
        isEditable = true
        uriError = nil
    }
    
    private func connect(to url: String, normalizedURL: URL) {
        isLoading = true
        isEditable = false
        uriError = nil
        interactor.connect(url: url, normalizedURL: normalizedURL, allowTLSOff: allowTLSOff, login: username, password: password)
    }
    
    private func showStatus(_ status: BackupAddWebDAVModuleInteractorStatus) {
        isEditable = true
        isConnected = false
        isLoading = false

        switch status {
        case .idle, .notConfigured:
            uriError = nil
        case .syncing:
            isLoading = true
            uriError = nil
            isEditable = false
        case .unauthorized:
            uriError = String(localized: .syncStatusErrorNotAuthorized)
        case .forbidden:
            uriError = String(localized: .syncStatusErrorUserIsForbidden)
        case .syncError(let string):
            uriError = {
                if let string {
                    return String(localized: .syncStatusErrorGeneralReason(string))
                }
                return String(localized: .commonGeneralErrorTryAgain)
            }()
        case .retrying(let string):
            isLoading = true
            uriError = {
                if let string {
                    return String(localized: .syncStatusRetryingDetails(string))
                }
                return String(localized: .syncStatusRetrying)
            }()
            isEditable = false
        case .networkError(let string):
            uriError = String(localized: .generalNetworkErrorDetails(string))
            isEditable = false
        case .serverError(let string):
            uriError = String(localized: .generalServerErrorDetails(string))
        case .synced:
            uriError = nil
            isConnected = true
            isEditable = false
        case .urlError:
            uriError = String(localized: .syncStatusErrorIncorrectUrl)
        case .sslError:
            uriError = String(localized: .syncStatusErrorTlsCertFailed)
        case .methodNotAllowed:
            uriError = String(localized: .syncStatusErrorNoWebDavServer)
        case .limitDevicesReached:
            destination = .upgradePlanPrompt
        case .passwordChanged:
            uriError = String(localized: .syncStatusErrorPasswordChanged)
        case .schemaNotSupported(let schemaVersion):
            uriError = String(localized: .cloudSyncInvalidSchemaErrorMsg(Int32(schemaVersion)))
        }
    }
}
