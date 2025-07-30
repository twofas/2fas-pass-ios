// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import CommonUI

enum QuickSetupDestination: RouterDestination {
    case defaultSecurityTier
    case importExport
    case transferItems
    case syncNotAllowed
}

@Observable
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

        await withTaskGroup() { group in
            group.addTask {
                await self.observePremiumPlanPrompt()
            }
            group.addTask {
                await self.observeAutoFillStatusChanged()
            }
            group.addTask {
                await self.observeCloudStatusChanged()
            }
        }
    }
    
    func onChangeDefaultSecurityTier() {
        destination = .defaultSecurityTier
    }
    
    func onImportItems() {
        destination = .importExport
    }
    
    func onTransferItems() {
        destination = .transferItems
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
    
    private func observeCloudStatusChanged() async {
        for await _ in interactor.didCloudStatusChanged {
            switch interactor.cloudState {
            case .disabledNotAvailable:
                showVaultSyncFailure = true
            default:
                break
            }
            
            _iCloudSyncEnabled = interactor.isCloudEnabled
        }
    }
}
