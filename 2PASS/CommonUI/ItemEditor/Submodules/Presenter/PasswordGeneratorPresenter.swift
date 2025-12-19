// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

@Observable
final class PasswordGeneratorPresenter {
    
    let minPasswordLength: Int
    let maxPasswordLength: Int
    
    private var passwordText = ""
    var password: AttributedString = .init()
    
    var passwordLength: Int {
        didSet {
            if oldValue != passwordLength {
                generate()
            }
        }
    }
    
    var hasDigits = true {
        didSet {
            generate()
        }
    }
    
    var hasUppercase = true {
        didSet {
            generate()
        }
    }
    
    var hasSpecial = true {
        didSet {
            generate()
        }
    }
    
    private let close: Callback
    private let closeUsePassword: (String) -> Void
    private let interactor: PasswordGeneratorModuleInteracting

    init(
        close: @escaping Callback,
        closeUsePassword: @escaping (String) -> Void,
        interactor: PasswordGeneratorModuleInteracting
    ) {
        self.close = close
        self.closeUsePassword = closeUsePassword
        self.interactor = interactor
        
        self.minPasswordLength = interactor.minPasswordLength
        self.maxPasswordLength = interactor.maxPasswordLength
        self.passwordLength = interactor.prefersPasswordLength
    }
}

extension PasswordGeneratorPresenter {
    
    func onAppear() {
        if let config = interactor.configuration {
            self.passwordLength = config.length
            self.hasDigits = config.hasDigits
            self.hasUppercase = config.hasUppercase
            self.hasSpecial = config.hasSpecial
        }
        generate()
    }
    
    func onGenerate() {
        generate()
    }
    
    func onCopy() {
        interactor.copyPassword(passwordText)
        ToastPresenter.shared.presentPasswordCopied()
    }
    
    func onUse() {
        interactor.saveConfig(config)
        closeUsePassword(passwordText)
    }
    
    func onClose() {
        interactor.saveConfig(config)
        close()
    }
}

private extension PasswordGeneratorPresenter {
    
    private func generate() {
        let pass = interactor.generatePassword(using: config)
        passwordText = pass

        let attrPass = colorizePassword(pass.withZeroWidthSpaces)
        password = attrPass
    }
    
    private var config: PasswordGenerateConfig {
        .init(length: passwordLength, hasDigits: hasDigits, hasUppercase: hasUppercase, hasSpecial: hasSpecial)
    }
    
    private func colorizePassword(_ password: String) -> AttributedString {
        PasswordRenderer(password: password).makeColorizedAttributedString()
    }
}
