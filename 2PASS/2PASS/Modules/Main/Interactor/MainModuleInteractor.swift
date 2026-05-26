// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

protocol MainModuleInteracting: AnyObject {
    var paymentScreen: Callback? { get set }
    var badgeUpdates: AsyncStream<Bool> { get }
    var shouldShowQuickSetup: Bool { get }
    var shouldRequestForBiometryToLogin: Bool { get }

    func viewIsVisible()
}

final class MainModuleInteractor {
    var paymentScreen: Callback?

    private let syncTriggerInteractor: BackupSyncTriggerInteracting
    private let quickSetupInteractor: QuickSetupInteracting
    private let loginInteractor: LoginInteracting
    private let notificationCenter: NotificationCenter

    init(
        syncTriggerInteractor: BackupSyncTriggerInteracting,
        quickSetupInteractor: QuickSetupInteracting,
        loginInteractor: LoginInteracting
    ) {
        self.syncTriggerInteractor = syncTriggerInteractor
        self.quickSetupInteractor = quickSetupInteractor
        self.loginInteractor = loginInteractor
        self.notificationCenter = NotificationCenter.default

        notificationCenter.addObserver(
            self,
            selector: #selector(userLoggedIn),
            name: .userLoggedIn,
            object: nil
        )
        notificationCenter.addObserver(
                self,
                selector: #selector(presentPaymentScreen),
                name: .presentPaymentScreen,
                object: nil
            )
    }

    deinit {
        notificationCenter.removeObserver(self)
    }
}

extension MainModuleInteractor: MainModuleInteracting {
    var shouldRequestForBiometryToLogin: Bool {
        loginInteractor.shouldRequestForBiometryToLogin
    }

    var shouldShowQuickSetup: Bool {
        quickSetupInteractor.shouldShowQuickSetup
    }

    var badgeUpdates: AsyncStream<Bool> {
        syncTriggerInteractor.syncErrorChanges
    }

    func viewIsVisible() {
        Log("MainModuleInteractor - Main is visible", module: .moduleInteractor)
        sync()
    }
}

private extension MainModuleInteractor {
    @objc
    func userLoggedIn() {
        Log("MainModuleInteractor - user logged in", module: .moduleInteractor)
        sync()
    }

    @objc
    func presentPaymentScreen() {
        paymentScreen?()
    }

    func sync() {
        Log("MainModuleInteractor - triggering sync on Main", module: .moduleInteractor)
        syncTriggerInteractor.syncAll()
    }
}
