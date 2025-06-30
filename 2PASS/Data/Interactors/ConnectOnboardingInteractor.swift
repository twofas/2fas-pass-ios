// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public protocol ConnectOnboardingInteracting: AnyObject {
    var isOnboardingCompleted: Bool { get }
    func finishOnboarding()
}

final class ConnectOnboardingInteractor: ConnectOnboardingInteracting {
    
    let mainRepository: MainRepository
    
    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }
    
    var isOnboardingCompleted: Bool {
        mainRepository.isConnectOnboardingCompleted
    }
    
    func finishOnboarding() {
        mainRepository.finishConnectOnboarding()
    }
}
