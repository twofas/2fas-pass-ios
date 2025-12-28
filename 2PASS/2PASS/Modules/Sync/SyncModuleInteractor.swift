// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

protocol SyncModuleInteracting: AnyObject {
    var isCloudEnabled: Bool { get }
    var cloudState: CloudState { get }
    var cloudStateChanged: Callback? { get set }
    var cloudLastSuccessSyncDate: Date? { get }
    func turnOnCloud()
    func turnOffCloud()
    
    var isWebDAVEnabled: Bool { get }
    var webDAVState: WebDAVState { get }
    var webDAVStateChanged: Callback? { get set }
    var webDAVLastSyncDate: Date? { get }
    func disableWebDAV()
}

final class SyncModuleInteractor {
    private let cloudSyncInteractor: CloudSyncInteracting
    private let webDAVStateInteractor: WebDAVStateInteracting
    private let notificationCenter: NotificationCenter

    private(set) var cloudState: CloudState = .unknown
    var cloudStateChanged: Callback?
    var webDAVStateChanged: Callback?

    init(cloudSyncInteractor: CloudSyncInteracting, webDAVStateInteractor: WebDAVStateInteracting) {
        self.cloudSyncInteractor = cloudSyncInteractor
        self.webDAVStateInteractor = webDAVStateInteractor
        notificationCenter = NotificationCenter.default
        
        cloudState = cloudSyncInteractor.currentState
        notificationCenter.addObserver(self, selector: #selector(cloudStateDidChanged), name: .cloudStateChanged, object: nil)
        notificationCenter.addObserver(self, selector: #selector(webDAVStateDidChanged), name: .webDAVStateChange, object: nil)
    }
    
    deinit {
        notificationCenter.removeObserver(self)
    }
}

extension SyncModuleInteractor: SyncModuleInteracting {
    
    var cloudLastSuccessSyncDate: Date? {
        cloudSyncInteractor.lastSuccessSyncDate
    }
    
    var isCloudEnabled: Bool {
        if case .enabled = cloudState {
            return true
        } else if case .enabledNotAvailable = cloudState {
            return true
        } else {
            return false
        }
    }
    
    var webDAVLastSyncDate: Date? {
        webDAVStateInteractor.lastSyncDate
    }
    
    var webDAVState: WebDAVState {
        webDAVStateInteractor.state
    }
    
    var isWebDAVEnabled: Bool {
        webDAVStateInteractor.isConnected
    }
    
    func disableWebDAV() {
        webDAVStateInteractor.disconnect()
    }
    
    @objc
    private func cloudStateDidChanged() {
        cloudState = cloudSyncInteractor.currentState
        cloudStateChanged?()
    }
    
    @objc
    private func webDAVStateDidChanged() {
        webDAVStateChanged?()
    }
    
    func turnOnCloud() {
        switch cloudSyncInteractor.currentState {
        case .disabled: cloudSyncInteractor.enable()
        default: break
        }
    }
    
    func turnOffCloud() {
        switch cloudSyncInteractor.currentState {
        case .enabled, .enabledNotAvailable: cloudSyncInteractor.disable()
        default: break
        }
    }
}
