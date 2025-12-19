// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Data
import Common

protocol PasswordGeneratorModuleInteracting: AnyObject {
    var configuration: PasswordGenerateConfig? { get }
    var minPasswordLength: Int { get }
    var maxPasswordLength: Int { get }
    var prefersPasswordLength: Int { get }

    func saveConfig(_ config: PasswordGenerateConfig)
    func generatePassword(using config: PasswordGenerateConfig) -> String
    func copyPassword(_ password: String)
}

final class PasswordGeneratorModuleInteractor {
    
    private let passwordGeneratorInteractor: PasswordGeneratorInteracting
    private let systemInteractor: SystemInteracting
    private let configInteractor: ConfigInteracting
    
    init(passwordGenerator: PasswordGeneratorInteracting, systemInteractor: SystemInteracting, configInteractor: ConfigInteracting) {
        self.systemInteractor = systemInteractor
        self.configInteractor = configInteractor
        self.passwordGeneratorInteractor = passwordGenerator
    }
}

extension PasswordGeneratorModuleInteractor: PasswordGeneratorModuleInteracting {
    
    var minPasswordLength: Int {
        passwordGeneratorInteractor.minPasswordLength
    }
    
    var maxPasswordLength: Int {
        passwordGeneratorInteractor.maxPasswordLength
    }
    
    var prefersPasswordLength: Int {
        passwordGeneratorInteractor.prefersPasswordLength
    }
    
    var configuration: PasswordGenerateConfig? {
        configInteractor.passwordGeneratorConfig
    }
    
    func saveConfig(_ config: PasswordGenerateConfig) {
        configInteractor.savePasswordGeneratorConfig(config)
    }
    
    func copyPassword(_ password: String) {
        systemInteractor.copyToClipboard(password)
    }
    
    func generatePassword(using config: PasswordGenerateConfig) -> String {
        passwordGeneratorInteractor.generatePassword(using: config)
    }
}
