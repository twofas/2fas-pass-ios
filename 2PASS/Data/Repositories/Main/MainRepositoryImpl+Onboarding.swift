// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

extension MainRepositoryImpl {
 
    var isOnboardingCompleted: Bool {
        userDefaultsDataSource.isOnboardingCompleted
    }
    
    var isConnectOnboardingCompleted: Bool {
        userDefaultsDataSource.isConnectOnboardingCompleted
    }
    
    func finishOnboarding() {
        userDefaultsDataSource.onboardingCompleted(true)
    }
    
    func finishConnectOnboarding() {
        userDefaultsDataSource.connectOnboardingCompleted(true)
    }
}
