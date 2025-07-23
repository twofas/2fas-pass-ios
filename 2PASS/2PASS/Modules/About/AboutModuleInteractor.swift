// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Data
import FirebaseCrashlytics

protocol AboutModuleInteracting: AnyObject {
    var appVersion: String { get }
    
    var isCrashReportsEnabled: Bool { get }
    func setCrashReportsEnabled(_ enabled: Bool)
}

final class AboutModuleInteractor: AboutModuleInteracting {
    
    private let systemInteractor: SystemInteracting
    
    init(systemInteractor: SystemInteracting) {
        self.systemInteractor = systemInteractor
    }
    
    var appVersion: String {
        systemInteractor.appVersion
    }
    
    var isCrashReportsEnabled: Bool {
        Crashlytics.crashlytics().isCrashlyticsCollectionEnabled()
    }
    
    func setCrashReportsEnabled(_ enabled: Bool) {
        Crashlytics.crashlytics().setCrashlyticsCollectionEnabled(enabled)
    }
}
