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
        // Belt-and-suspenders: `VaultRecoveryRecoverModuleInteractor.persistRecoverySource`
        // already clears on disk-save success; this guards against future code paths that
        // reach `finishVaultRecovery` via a route that bypasses `persistRecoverySource`.
        cacheInteractor.clearCachedConfigs()
        mainrepository.finishOnboarding()
    }

    func finishVaultCreation() {
        // Defensive: the recovery flow and the create-new-vault flow are mutually exclusive
        // branches of the onboarding nav stack, so this call is a no-op in normal flow. Kept
        // for forward-safety if a future refactor enables cross-branch state.
        cacheInteractor.clearCachedConfigs()
        mainrepository.setShouldShowQuickSetup(true)
        mainrepository.finishOnboarding()
    }
}
