// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Data

protocol PremiumPromptModuleInteracting {
    var allowsUpgrade: Bool { get }
}

class PremiumPromptModuleInteractor: PremiumPromptModuleInteracting {
    
    let systemInteractor: SystemInteracting
    
    init(systemInteractor: SystemInteracting) {
        self.systemInteractor = systemInteractor
    }
    
    var allowsUpgrade: Bool {
        systemInteractor.isMainAppProcess
    }
}
