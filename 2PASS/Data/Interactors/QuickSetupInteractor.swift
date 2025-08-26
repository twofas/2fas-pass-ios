// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public protocol QuickSetupInteracting: AnyObject {
    var shouldShowQuickSetup: Bool { get }
    func finishQuickSetup()
}

final class QuickSetupInteractor: QuickSetupInteracting {
    
    private let mainRepository: MainRepository
    
    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }
    
    var shouldShowQuickSetup: Bool {
        mainRepository.shouldShowQuickSetup
    }
    
    func finishQuickSetup() {
        mainRepository.setShouldShowQuickSetup(false)
    }
}
