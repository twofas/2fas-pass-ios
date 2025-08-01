// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Data

protocol SetupCompleteModuleInteracting: AnyObject {
    func finish()
}

final class SetupCompleteModuleInteractor: SetupCompleteModuleInteracting {

    let interactor: OnboardingInteracting
    
    init(onboardingInteractor: OnboardingInteracting) {
        self.interactor = onboardingInteractor
    }
    
    func finish() {
        interactor.finishVaultCreation()
    }
}
