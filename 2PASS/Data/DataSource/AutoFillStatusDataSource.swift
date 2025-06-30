// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import AuthenticationServices

protocol AutoFillStatusDataSourcing: AnyObject {
    var isEnabled: Bool { get }
    var didStatusChanged: NotificationCenter.Notifications { get }
    
    @discardableResult
    func refreshStatus() async -> Bool

    @available(iOS 18.0, *)
    func requestAutoFillPermissions() async
}

final class AutoFillStatusDataSource: AutoFillStatusDataSourcing {

    private static let didChangeNotification = Notification.Name("AutoFillStatusDidChange")
    
    var didStatusChanged: NotificationCenter.Notifications {
        NotificationCenter.default.notifications(named: AutoFillStatusDataSource.didChangeNotification)
    }
    
    private(set) var isEnabled: Bool = false {
        didSet {
            guard isEnabled != oldValue else {
                return
            }
            
            NotificationCenter.default.post(name: AutoFillStatusDataSource.didChangeNotification, object: nil)
        }
    }
    
    private let store = ASCredentialIdentityStore.shared
    
    private var didBecomeActiveObserver: Task<Void, Never>?
    
    init() {
        Task {
            await refreshStatus()
        }
        
        didBecomeActiveObserver = Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
                await self?.refreshStatus()
            }
        }
    }
    
    @available(iOS 18.0, *)
    func requestAutoFillPermissions() async {
        let isEnabled = await ASSettingsHelper.requestToTurnOnCredentialProviderExtension()
        Task { @MainActor in
            self.isEnabled = isEnabled
        }
    }
    
    deinit {
        didBecomeActiveObserver?.cancel()
    }
    
    @discardableResult
    func refreshStatus() async -> Bool {
        let isEnabled = await store.state().isEnabled
        Task { @MainActor in
            self.isEnabled = isEnabled
        }
        return isEnabled
    }
}
