// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import CommonUI
import Data
import Backup

enum QuickSetupDestination: RouterDestination {
    case defaultSecurityTier
    case importExport(onClose: Callback)
    case transferItems(onClose: Callback)
    case syncNotAllowed
    
    var id: String {
        switch self {
        case .defaultSecurityTier:
            "defaultSecurityTier"
        case .importExport:
            "importExport"
        case .transferItems:
            "transferItems"
        case .syncNotAllowed:
            "syncNotAllowed"
        }
    }
}

@MainActor @Observable
final class QuickSetupPresenter {
 
    var destination: QuickSetupDestination?
    var showVaultSyncFailure = false
    
    var autofillIsEnabled: Bool {
        get {
            _autofillIsEnabled
        }
        set {
            if newValue {
                interactor.turnOnAutoFill()
            } else {
                interactor.turnOffAutoFill()
            }
        }
    }
    private var _autofillIsEnabled: Bool = false
    
    var iCloudSyncEnabled: Bool {
        get {
            _iCloudSyncEnabled
        }
        set {
            if newValue {
                interactor.turnOnCloud()
            } else {
                interactor.turnOffCloud()
            }
            
            _iCloudSyncEnabled = newValue
        }
    }
    private var _iCloudSyncEnabled: Bool = false
    
    private(set) var defaultSecurityTier: ItemProtectionLevel
    
    private let interactor: QuickSetupModuleInteracting
    
    init(interactor: QuickSetupModuleInteracting) {
        self.interactor = interactor
        self._autofillIsEnabled = interactor.isAutoFillEnabled
        self._iCloudSyncEnabled = interactor.isCloudEnabled
        self.defaultSecurityTier = interactor.defaultSecurityTier
    }
    
    func onAppear() async {
        defaultSecurityTier = interactor.defaultSecurityTier
        // Re-seed iCloud-toggle state once on appear in case a config was added/removed while
        // this screen was off-stack — covers the gap between init-time seeding and the
        // `BackupConfigsDidChange` subscription starting below.
        _iCloudSyncEnabled = interactor.isCloudEnabled

        await withTaskGroup() { group in
            group.addTask {
                await self.observePremiumPlanPrompt()
            }
            group.addTask {
                await self.observeAutoFillStatusChanged()
            }
            group.addTask {
                await self.observeConfigsChanged()
            }
        }
    }
    
    func onChangeDefaultSecurityTier() {
        destination = .defaultSecurityTier
    }
    
    func onImportItems() {
        destination = .importExport(onClose: { [weak self] in
            self?.destination = nil
        })
    }
    
    func onTransferItems() {
        destination = .transferItems(onClose: { [weak self] in
            self?.destination = nil
        })
    }
    
    func onClose() {
        interactor.finishQuickSetup()
    }
    
    private func observeAutoFillStatusChanged() async {
        for await _ in interactor.didAutoFillStatusChanged {
            _autofillIsEnabled = interactor.isAutoFillEnabled
        }
    }
    
    private func observePremiumPlanPrompt() async {
        for await _ in interactor.syncPremiumNeededScreen {
            destination = .syncNotAllowed
        }
    }

    /// Refreshes the iCloud-toggle mirror whenever `BackupSyncConfigsInteractor` posts a
    /// successful add / update / remove. Covers cross-screen changes (e.g. iCloud added via
    /// vault recovery or removed via the BackupConfigs screen) that don't pass through this
    /// presenter's own `turnOnCloud` / `turnOffCloud` setters.
    private func observeConfigsChanged() async {
        for await _ in NotificationCenter.default.messages(of: BackupConfigsDidChange.self) {
            _iCloudSyncEnabled = interactor.isCloudEnabled
        }
    }
}
