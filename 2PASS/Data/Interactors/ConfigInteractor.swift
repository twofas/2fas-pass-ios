// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public protocol ConfigInteracting: AnyObject {
    var currentDefaultProtectionLevel: ItemProtectionLevel { get }
    func setDefaultProtectionLevel(_ value: ItemProtectionLevel)
    
    var passwordGeneratorConfig: PasswordGenerateConfig? { get }
    func savePasswordGeneratorConfig(_ config: PasswordGenerateConfig)
    
    var deviceName: String { get }
    var defaultPassswordListAction: PasswordListAction { get }
    func setDefaultPassswordListAction(_ action: PasswordListAction)
    
    var appLockAttempts: AppLockAttempts { get }
    func setAppLockAttempts(_ attempts: AppLockAttempts)
}

final class ConfigInteractor {
    private let mainRepository: MainRepository
    
    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }
}

extension ConfigInteractor: ConfigInteracting {
    
    var deviceName: String {
        mainRepository.deviceName
    }
    
    var defaultPassswordListAction: PasswordListAction {
        mainRepository.defaultPassswordListAction
    }
    
    func setDefaultPassswordListAction(_ action: PasswordListAction) {
        mainRepository.setDefaultPassswordListAction(action)
    }
    
    var currentDefaultProtectionLevel: ItemProtectionLevel {
        mainRepository.currentDefaultProtectionLevel
    }
    
    func setDefaultProtectionLevel(_ value: ItemProtectionLevel) {
        Log("ConfigInteractor: Setting default protection level: \(value)", module: .interactor)
        mainRepository.setDefaultProtectionLevel(value)
    }
    
    var passwordGeneratorConfig: PasswordGenerateConfig? {
        guard let configData = mainRepository.passwordGeneratorConfig else {
            return nil
        }
        guard let config = try? mainRepository.jsonDecoder.decode(PasswordGenerateConfig.self, from: configData) else {
            Log("ConfigInteractor: Can't decode Password Generator Config for saving", module: .interactor)
            return nil
        }
        return config
    }
    
    func savePasswordGeneratorConfig(_ config: PasswordGenerateConfig) {
        guard let encodedData = try? mainRepository.jsonEncoder.encode(config) else {
            Log("ConfigInteractor: Can't encode Password Generator Config for saving", module: .interactor)
            return
        }
        mainRepository.setPasswordGeneratorConfig(encodedData)
    }
    
    var appLockAttempts: AppLockAttempts {
        mainRepository.appLockAttempts
    }
    
    func setAppLockAttempts(_ attempts: AppLockAttempts) {
        mainRepository.setAppLockAttempts(attempts)
    }
}
