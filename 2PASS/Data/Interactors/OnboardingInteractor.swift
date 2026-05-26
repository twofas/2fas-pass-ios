// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public protocol OnboardingInteracting: AnyObject {
    var isOnboardingCompleted: Bool { get }
    
    func finishVaultCreation()
    func finishVaultRecovery()
}

final class OnboardingInteractor {

    let mainrepository: MainRepository
    private let cacheInteractor: VaultRecoveryCacheInteracting

    init(
        mainRepository: MainRepository,
        cacheInteractor: VaultRecoveryCacheInteracting
    ) {
        self.mainrepository = mainRepository
        self.cacheInteractor = cacheInteractor
    }
}

extension OnboardingInteractor: OnboardingInteracting {

    var isOnboardingCompleted: Bool {
        mainrepository.isOnboardingCompleted
    }

    func finishVaultRecovery() {
        cacheInteractor.clearCachedConfigs()
        mainrepository.finishOnboarding()
    }

    func finishVaultCreation() {
        cacheInteractor.clearCachedConfigs()
        mainrepository.setShouldShowQuickSetup(true)
        mainrepository.finishOnboarding()
    }
}
