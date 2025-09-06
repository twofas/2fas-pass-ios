// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

public final class ModuleInteractorFactory {
    public static let shared = ModuleInteractorFactory()
    
    public func loginModuleInteractor(config: LoginModuleInteractorConfig) -> LoginModuleInteracting {
        LoginModuleInteractor(
            config: config,
            loginInteractor: InteractorFactory.shared.loginInteractor()
        )
    }
    
    func customizeIconInteractor() -> CustomizeIconModuleInteracting {
        CustomizeIconModuleInteractor(
            fileIconInteractor: InteractorFactory.shared.fileIconInteractor()
        )
    }
    
    func addPasswordInteractor(editPasswordID: PasswordID?, changeRequest: PasswordDataChangeRequest? = nil) -> AddPasswordModuleInteracting {
        AddPasswordModuleInteractor(
            itemsInteractor: InteractorFactory.shared.itemsInteractor(),
            configInteractor: InteractorFactory.shared.configInteractor(),
            uriInteractor: InteractorFactory.shared.uriInteractor(),
            syncChangeTriggerInteractor: InteractorFactory.shared.syncChangeTriggerInteractor(callsChange: false),
            autoFillCredentialsInteractor: InteractorFactory.shared.autoFillCredentialsInteractor(),
            passwordGeneratorInteractor: InteractorFactory.shared.passwordGeneratorInteractor(),
            fileIconInteractor: InteractorFactory.shared.fileIconInteractor(),
            currentDateInteractor: InteractorFactory.shared.currentDateInteractor(),
            passwordListInteractor: InteractorFactory.shared.passwordListInteractor(),
            tagInteractor: InteractorFactory.shared.tagInteractor(),
            editPasswordID: editPasswordID,
            changeRequest: changeRequest
        )
    }
    
    func passwordInteractor() -> PasswordsModuleInteracting {
        PasswordsModuleInteractor(
            itemsInteractor: InteractorFactory.shared.itemsInteractor(),
            fileIconInteractor: InteractorFactory.shared.fileIconInteractor(),
            systemInteractor: InteractorFactory.shared.systemInteractor(),
            uriInteractor: InteractorFactory.shared.uriInteractor(),
            syncChangeTriggerInteractor: InteractorFactory.shared.syncChangeTriggerInteractor(callsChange: false),
            autoFillCredentialsInteractor: InteractorFactory.shared.autoFillCredentialsInteractor(),
            configInteractor: InteractorFactory.shared.configInteractor(),
            paymentStatusInteractor: InteractorFactory.shared.paymentStatusInteractor(),
            passwordListInteractor: InteractorFactory.shared.passwordListInteractor(),
            tagInteractor: InteractorFactory.shared.tagInteractor()
        )
    }
    
    func addPasswordGenerateModuleInteractor() -> AddPasswordGenerateModuleInteracting {
        AddPasswordGenerateModuleInteractor(
            passwordGenerator: InteractorFactory.shared.passwordGeneratorInteractor(),
            systemInteractor: InteractorFactory.shared.systemInteractor(),
            configInteractor: InteractorFactory.shared.configInteractor()
        )
    }
    
    func viewPasswordInteractor() -> ViewPasswordModuleInteracting {
        ViewPasswordModuleInteractor(
            itemsInteractor: InteractorFactory.shared.itemsInteractor(),
            systemInteractor: InteractorFactory.shared.systemInteractor(),
            fileIconInteractor: InteractorFactory.shared.fileIconInteractor(),
            uriInteractor: InteractorFactory.shared.uriInteractor(),
            tagInteractor: InteractorFactory.shared.tagInteractor()
        )
    }
    
    func biometricPromptModuleInteractor() -> BiometricPromptModuleInteracting {
        BiometricPromptModuleInteractor(
            biometryInteractor: InteractorFactory.shared.biometryInteractor(),
            loginInteractor: InteractorFactory.shared.loginInteractor()
        )
    }
    
    func premiumPromptModuleInteractor() -> PremiumPromptModuleInteracting {
        PremiumPromptModuleInteractor(systemInteractor: InteractorFactory.shared.systemInteractor())
    }
    
    func selectTagsModuleInteractor() -> SelectTagsModuleInteracting {
        SelectTagsModuleInteractor(
            tagInteractor: InteractorFactory.shared.tagInteractor()
        )
    }
    
    func editTagModuleInteractor() -> EditTagModuleInteracting {
        EditTagModuleInteractor(
            tagInteractor: InteractorFactory.shared.tagInteractor(),
            syncChangeTriggerInteractor: InteractorFactory.shared.syncChangeTriggerInteractor(callsChange: false)
        )
    }
}
