// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Data
import Common

protocol SettingsDebugModuleInteracting: AnyObject {
    var appVersion: String { get }
    
    var debugSubscriptionPlan: SubscriptionPlan? { get }
    func setDebugSubscriptionPlan(_ plan: SubscriptionPlan)
    func clearDebugSubscriptionPlan()
}

final class SettingsDebugModuleInteractor: SettingsDebugModuleInteracting {
    
    private let systemInteractor: SystemInteracting
    private let debugInteractor: DebugInteracting
    
    init(systemInteractor: SystemInteracting, debugInteractor: DebugInteracting) {
        self.systemInteractor = systemInteractor
        self.debugInteractor = debugInteractor
    }
    
    var appVersion: String {
        "\(systemInteractor.appVersion) (\(systemInteractor.buildVersion))"
    }
    
    var debugSubscriptionPlan: SubscriptionPlan? {
        debugInteractor.isOverridedSubscriptionPlan ? debugInteractor.subscriptionPlan : nil
    }
    
    func setDebugSubscriptionPlan(_ plan: SubscriptionPlan) {
        debugInteractor.overrideSubscriptionPlan(plan)
    }
    
    func clearDebugSubscriptionPlan() {
        debugInteractor.clearOverrideSubscriptionPlan()
    }
}
