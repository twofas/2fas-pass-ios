// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public protocol OnboardingInteracting: AnyObject {
    var isOnboardingCompleted: Bool { get }
    func finish()
}

final class OnboardingInteractor {

    let mainrepository: MainRepository
    
    init(mainRepository: MainRepository) {
        self.mainrepository = mainRepository
    }
}

extension OnboardingInteractor: OnboardingInteracting {
    
    var isOnboardingCompleted: Bool {
        mainrepository.isOnboardingCompleted
    }
    
    func finish() {
        mainrepository.finishOnboarding()
    }
}
