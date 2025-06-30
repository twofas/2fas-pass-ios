// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CommonUI
import Common

enum SettingsDebugDestination: RouterDestination {
    case eventLog
    case appState
    case generatePasswords
    case modifyState
    
    var id: Self {
        self
    }
}

@Observable
final class SettingsDebugPresenter {
    var destination: SettingsDebugDestination?

    var version: String {
        interactor.appVersion
    }
    
    var debugSubscriptionPlanType: SubscriptionPlanType? {
        didSet {
            switch debugSubscriptionPlanType {
            case .free:
                interactor.setDebugSubscriptionPlan(.free)
            case .premium:
                interactor.setDebugSubscriptionPlan(SubscriptionPlan(planType: .premium, paymentInfo: .init(expirationDate: Date(timeIntervalSinceNow: 60 * 60 * 24), willRenew: true)))
            case nil:
                interactor.clearDebugSubscriptionPlan()
            }
        }
    }
    
    private let interactor: SettingsDebugModuleInteracting
    
    init(interactor: SettingsDebugModuleInteracting) {
        self.interactor = interactor
        self.debugSubscriptionPlanType = interactor.debugSubscriptionPlan?.planType
    }
    
    func onEventLog() {
        destination = .eventLog
    }
    
    func onAppState() {
        destination = .appState
    }
    
    func onGeneratePasswords() {
        destination = .generatePasswords
    }
    
    func onModifyState() {
        destination = .modifyState
    }
}
