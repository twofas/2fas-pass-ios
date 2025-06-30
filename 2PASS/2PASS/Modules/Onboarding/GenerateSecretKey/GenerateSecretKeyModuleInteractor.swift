// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data

protocol GenerateSecretKeyModuleInteracting: AnyObject {
    var words: [String]? { get }
    func setupEncryptionElements()
}

final class GenerateSecretKeyModuleInteractor {
    private let startupInteractor: StartupInteracting
    
    init(
        startupInteractor: StartupInteracting
    ) {
        self.startupInteractor = startupInteractor
    }
}

extension GenerateSecretKeyModuleInteractor: GenerateSecretKeyModuleInteracting {
    
    var words: [String]? {
        startupInteractor.words
    }
    
    func setupEncryptionElements() {
        startupInteractor.setupEncryptionElements()
    }
}
