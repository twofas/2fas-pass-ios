// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common
import CommonUI

extension ModuleInteractorFactory {
    
    func rootModuleInteractor() -> RootModuleInteracting {
        RootModuleInteractor(
            rootInteractor: InteractorFactory.shared.rootInteractor(),
            startupInteractor: InteractorFactory.shared.startupInteractor(),
            securityInteractor: InteractorFactory.shared.securityInteractor(),
            syncInteractor: InteractorFactory.shared.cloudSyncInteractor(),
            appNotificationsInteractor: InteractorFactory.shared.appNotificationsInteractor(),
            timeVerificationInteractor: InteractorFactory.shared.timeVerificationInteractor(),
            paymentHandlingInteractor: InteractorFactory.shared.paymentHandlingInteractor(),
            onboardingInteractor: InteractorFactory.shared.onboardingInteractor()
        )
    }
    
    func masterPasswordInteractor(setupEncryption: Bool) -> MasterPasswordModuleInteracting {
        MasterPasswordModuleInteractor(
            startupInteractor: InteractorFactory.shared.startupInteractor(),
            setupEncryption: setupEncryption
        )
    }
    
    func changeMasterPasswordInteractor() -> MasterPasswordModuleInteracting {
        ChangeMasterPasswordModuleInteractor(
            changePasswordInteractor: InteractorFactory.shared.changePasswordInteractor()
        )
    }
    
    func settingsInteractor() -> SettingsModuleInteracting {
        SettingsModuleInteractor(
            systemInteractor: InteractorFactory.shared.systemInteractor(),
            configInteractor: InteractorFactory.shared.configInteractor(),
            cloudSyncInteractor: InteractorFactory.shared.cloudSyncInteractor(),
            webDAVStateInteractor: InteractorFactory.shared.webDAVStateInteractor(),
            autoFillStatusInteractor: InteractorFactory.shared.autoFillStatusInteractor(),
            pushNotificationsInteractor: InteractorFactory.shared.pushNotificationsPermissionInteractor(),
            paymentStatusInteractor: InteractorFactory.shared.paymentStatusInteractor()
        )
    }
    
    func trashInteractor() -> TrashModuleInteracting {
        TrashModuleInteractor(
            passwordInteractor: InteractorFactory.shared.passwordInteractor(),
            fileIconInteractor: InteractorFactory.shared.fileIconInteractor(),
            syncChangeTriggerInteractor: InteractorFactory.shared.syncChangeTriggerInteractor(callsChange: false),
            paymentStatusInteractor: InteractorFactory.shared.paymentStatusInteractor()
        )
    }
    
    func recoveryKitOnboardingModuleInteractor() -> RecoveryKitModuleInteracting {
        RecoveryKitOnboardingModuleInteractor(
            startupInteractor: InteractorFactory.shared.startupInteractor(),
            recoveryKitInteractor: InteractorFactory.shared.recoveryKitInteractor(
                translations: .default,
                pdfConfig: .default
            )
        )
    }
    
    func recoveryKitSettingsModuleInteractor() -> RecoveryKitModuleInteracting {
        RecoveryKitSettingsModuleInteractor(
            protectionInteractor: InteractorFactory.shared.protectionInteractor(),
            recoveryKitInteractor: InteractorFactory.shared.recoveryKitInteractor(
            translations: .default,
            pdfConfig: .default
        ))
    }
    
    func enterWordsModuleInteractor() -> EnterWordsModuleInteracting {
        EnterWordsModuleInteractor(
            cameraPermissionInteractor: InteractorFactory.shared.cameraPermissionsInteractor(),
            startupInteractor: InteractorFactory.shared.startupInteractor(),
            importInteractor: InteractorFactory.shared.importInteractor()
        )
    }
    
    func eventLogModuleInteractor() -> EventLogModuleInteracting {
        EventLogModuleInteractor(
            debugInteractor: InteractorFactory.shared.debugInteractor()
        )
    }
    
    func appStateModuleInteractor() -> AppStateModuleInteracting {
        AppStateModuleInteractor(
            debugInteractor: InteractorFactory.shared.debugInteractor()
        )
    }
    
    func modifyStateModuleInteractor() -> ModifyStateModuleInteracting {
        ModifyStateModuleInteractor(
            debugInteractor: InteractorFactory.shared.debugInteractor()
        )
    }
    
    func backupExportFileModuleInteractor() -> BackupExportFileModuleInteracting {
        BackupExportFileModuleInteractor(
            exportInteractor: InteractorFactory.shared.exportInteractor(),
            currentDateInteractor: InteractorFactory.shared.currentDateInteractor()
        )
    }
    
    func backupModuleInteractor() -> BackupModuleInteracting {
        BackupModuleInteractor(
            importInteractor: InteractorFactory.shared.backupImportInteractor(),
            passwordInteractor: InteractorFactory.shared.passwordInteractor(),
            biometryInteractor: InteractorFactory.shared.biometryInteractor(),
            loginInteractor: InteractorFactory.shared.loginInteractor(),
            protectionInteractor: InteractorFactory.shared.protectionInteractor(),
            paymentStatusInteractor: InteractorFactory.shared.paymentStatusInteractor()
        )
    }
    
    func backupImportImportingModuleInteractor(input: BackupImportInput) -> BackupImportImportingModuleInteracting {
        BackupImportImportingModuleInteractor(
            passwordImportInteractor: InteractorFactory.shared.passwordImportInteractor(),
            importInteractor: InteractorFactory.shared.importInteractor(),
            input: input
        )
    }
    
    func appSecurityModuleInteractor() -> AppSecurityModuleInteracting {
        AppSecurityModuleInteractor(
            loginInteractor: InteractorFactory.shared.loginInteractor(),
            biometryInteractor: InteractorFactory.shared.biometryInteractor(),
            protectionInteractor: InteractorFactory.shared.protectionInteractor(),
            configInteractor: InteractorFactory.shared.configInteractor()
        )
    }

    func vaultRecoveryModuleInteractor() -> VaultRecoveryModuleInteracting {
        VaultRecoveryModuleInteractor(
            startupInteractor: InteractorFactory.shared.startupInteractor()
        )
    }
    
    func vaultRecoveryEnterPasswordModuleInteractor(
        entropy: Entropy,
        recoveryData: VaultRecoveryData
    ) -> VaultRecoveryEnterPasswordModuleInteracting {
        VaultRecoveryEnterPasswordModuleInteractor(
            entropy: entropy,
            recoveryData: recoveryData,
            loginInteractor: InteractorFactory.shared.loginInteractor()
        )
    }
    
    func vaultRecoveryCheckModuleInteractor(url: URL) -> VaultRecoveryCheckModuleInteracting {
        VaultRecoveryCheckModuleInteractor(
            importInteractor: InteractorFactory.shared.backupImportInteractor(),
            url: url
        )
    }
    
    func backupAddWebDAVModuleInteractor() -> BackupAddWebDAVModuleInteracting {
        BackupAddWebDAVModuleInteractor(
            webDAVBackupInteractor: InteractorFactory.shared.webDAVBackupInteractor(),
            webDAVStateInteractor: InteractorFactory.shared.webDAVStateInteractor(),
            uriInteractor: InteractorFactory.shared.uriInteractor(),
            cloudSyncInteractor: InteractorFactory.shared.cloudSyncInteractor()
        )
    }
    
    func mainModuleInteracting() -> MainModuleInteracting {
        MainModuleInteractor(
            webDAVBackupInteractor: InteractorFactory.shared.webDAVBackupInteractor(),
            syncChangeTriggerInteractor: InteractorFactory.shared.syncChangeTriggerInteractor(callsChange: true),
            webDAVStateInteractor: InteractorFactory.shared.webDAVStateInteractor(),
            cloudSyncInteractor: InteractorFactory.shared.cloudSyncInteractor(),
            systemInteractor: InteractorFactory.shared.systemInteractor(),
            quickSetupInteractor: InteractorFactory.shared.quickSetupInteractor(),
            loginInteractor: InteractorFactory.shared.loginInteractor(),
        )
    }
    
    func generateContentModuleInteractor() -> GenerateContentModuleInteracting {
        GenerateContentModuleInteractor(
            debugInteractor: InteractorFactory.shared.debugInteractor(),
            syncChangeTriggerInteractor: InteractorFactory.shared.syncChangeTriggerInteractor(callsChange: false)
        )
    }
    
    func vaultRecoveryRecoverModuleInteractor(kind: VaultRecoveryRecoverKind) -> VaultRecoveryRecoverModuleInteracting {
        VaultRecoveryRecoverModuleInteractor(
            kind: kind,
            passwordImportInteractor: InteractorFactory.shared.passwordImportInteractor(),
            startupInteractor: InteractorFactory.shared.startupInteractor(),
            importInteractor: InteractorFactory.shared.importInteractor(),
            cloudSyncInteractor: InteractorFactory.shared.cloudSyncInteractor(),
            onboardingInteractor: InteractorFactory.shared.onboardingInteractor(),
            webDAVBackupInteractor: InteractorFactory.shared.webDAVBackupInteractor(ignoreDeviceId: true)
        )
    }
    
    func vaultRecoveryEnterWordsModuleInteractor() -> VaultRecoveryEnterWordsModuleInteracting {
        VaultRecoveryEnterWordsModuleInteractor(
            startupInteractor: InteractorFactory.shared.startupInteractor(),
            importInteractor: InteractorFactory.shared.importInteractor()
        )
    }
    
    func vaultRecoverySelectModuleInteractor() -> VaultRecoverySelectModuleInteracting {
        VaultRecoverySelectModuleInteractor(
            importInteractor: InteractorFactory.shared.importInteractor()
        )
    }
    
    func vaultRecoveryCameraModuleInteractor() -> VaultRecoveryCameraModuleInteracting {
        VaultRecoveryCameraModuleInteractor(
            cameraPermissionInteractor: InteractorFactory.shared.cameraPermissionsInteractor()
        )
    }
    
    func vaultRecoveryWebDAVModuleInteractor() -> VaultRecoveryWebDAVModuleInteracting {
        VaultRecoveryWebDAVModuleInteractor(
            webDAVRecoveryInteractor: InteractorFactory.shared.webDAVRecoveryInteractor(),
            uriInteractor: InteractorFactory.shared.uriInteractor()
        )
    }
    
    func vaultRecoverySelectWebDAVIndexModuleInteractor() -> VaultRecoverySelectWebDAVIndexModuleInteracting {
        VaultRecoverySelectWebDAVIndexModuleInteractor(
            webDAVRecoveryInteractor: InteractorFactory.shared.webDAVRecoveryInteractor()
        )
    }
    
    func generateSecretKeyModuleInteractor() -> GenerateSecretKeyModuleInteracting {
        GenerateSecretKeyModuleInteractor(
            startupInteractor: InteractorFactory.shared.startupInteractor()
        )
    }
    
    func vaultRecoveryiCloudVaultSelectionModuleInteractor() -> VaultRecoveryiCloudVaultSelectionModuleInteracting {
        VaultRecoveryiCloudVaultSelectionModuleInteractor(
            cloudRecoveryInteractor: InteractorFactory.shared.cloudRecoveryInteracting()
        )
    }
    
    func setupCompleteModuleInteractor() -> SetupCompleteModuleInteracting {
        SetupCompleteModuleInteractor(
            onboardingInteractor: InteractorFactory.shared.onboardingInteractor()
        )
    }
    
    func customizationModuleInteractor() -> CustomizationModuleInteracting {
        CustomizationModuleInteractor(configInteractor: InteractorFactory.shared.configInteractor())
    }
    
    func autoFillSettingsModuleInteractor() -> AutofillSettingsModuleInteracting {
        AutofillSettingsModuleInteractor(
            autoFillStatusInteractor: InteractorFactory.shared.autoFillStatusInteractor()
        )
    }
    
    @MainActor
    func knownBrowsersModuleInteractor() -> KnownBrowsersModuleInteracting {
        KnownBrowsersModuleInteractor(
            webBrowserInteractor: InteractorFactory.shared.webBrowsersInteractor(),
            identiconInteractor: InteractorFactory.shared.connectSecurityIconInteractor()
        )
    }
    
    @MainActor
    func aboutModuleInteractor() -> AboutModuleInteracting {
        AboutModuleInteractor(
            systemInteractor: InteractorFactory.shared.systemInteractor()
        )
    }
    
    @MainActor
    func settingsDebugInteractor() -> SettingsDebugModuleInteractor {
        SettingsDebugModuleInteractor(
            systemInteractor: InteractorFactory.shared.systemInteractor(),
            debugInteractor: InteractorFactory.shared.debugInteractor()
        )
    }
    
    @MainActor
    func syncModuleInteractor() -> SyncModuleInteracting {
        SyncModuleInteractor(
            cloudSyncInteractor: InteractorFactory.shared.cloudSyncInteractor(),
            webDAVStateInteractor: InteractorFactory.shared.webDAVStateInteractor()
        )
    }
    
    @MainActor
    func defaultSecurityTierModuleInteractor() -> DefaultSecurityTierModuleInteractor {
        DefaultSecurityTierModuleInteractor(
            configInteractor: InteractorFactory.shared.configInteractor()
        )
    }
    
    func connectModuleInteractor() -> ConnectModuleInteracting {
        ConnectModuleInteractor(
            cameraInteractor: InteractorFactory.shared.cameraPermissionsInteractor(),
            connectOnboardingInteractor: InteractorFactory.shared.connectOnboardingInteractor()
        )
    }
    
    func connectPermissionsModuleInteractor() -> ConnectPermissionsModuleInteracting {
        ConnectPermissionsModuleInteractor(
            cameraPermissionInteractor: InteractorFactory.shared.cameraPermissionsInteractor(),
            pushNotificationsPermissionInteractor: InteractorFactory.shared.pushNotificationsPermissionInteractor(),
            connectOnboardingInteractor: InteractorFactory.shared.connectOnboardingInteractor()
        )
    }
    
    func connectPullReqestCommunicationModuleInteractor(appNotification: AppNotification) -> ConnectPullReqestCommunicationModuleInteracting {
        ConnectPullReqestCommunicationModuleInteractor(
            appNotification: appNotification,
            connectInteractor: InteractorFactory.shared.connectInteractor(),
            identiconInteractor: InteractorFactory.shared.connectSecurityIconInteractor(),
            fileIconInteractor: InteractorFactory.shared.fileIconInteractor(),
            uriInteractor: InteractorFactory.shared.uriInteractor(),
            passwordInteractor: InteractorFactory.shared.passwordInteractor(),
            appNotificationsInteractor: InteractorFactory.shared.appNotificationsInteractor(),
            paymentStatusInteractor: InteractorFactory.shared.paymentStatusInteractor()
        )
    }
    
    func pushNotificationsModuleInteractor() -> PushNotificationsModuleInteracting {
        PushNotificationsModuleInteractor(pushNotificationsPermissionInteractor: InteractorFactory.shared.pushNotificationsPermissionInteractor())
    }
    
    func transferItemsInstructionsModuleInteractor(service: ExternalService) -> TransferItemsInstructionsModuleInteracting {
        TransferItemsInstructionsModuleInteractor(service: service, externalServiceImportInteractor: InteractorFactory.shared.externalServiceImportInteractor())
    }
    
    func transferItemsImportingModuleInteractor(service: ExternalService, passwords: [PasswordData]) -> TransferItemsImportingModuleInteracting {
        TransferItemsImportingModuleInteractor(
            service: service,
            passwords: passwords,
            passwordImportInteractor: InteractorFactory.shared.passwordImportInteractor()
        )
    }
    
    func transferItemsServicesListInteractor() -> TransferItemsServicesListInteracting {
        TransferItemsServicesListInteractor(
            passwordInteractor: InteractorFactory.shared.passwordInteractor(),
            paymentStatusInteractor: InteractorFactory.shared.paymentStatusInteractor()
        )
    }
    
    func connectCommunicationInteractor() -> ConnectCommunicationModuleInteracting {
        ConnectCommunicationModuleInteractor(
            connectInteractor: InteractorFactory.shared.connectInteractor(),
            securityIconInteractor: InteractorFactory.shared.connectSecurityIconInteractor(),
            webBrowsersInteractor: InteractorFactory.shared.webBrowsersInteractor(),
            paymentStatusInteractor: InteractorFactory.shared.paymentStatusInteractor()
        )
    }
    
    @MainActor
    func manageSubscriptionInteractor() -> ManageSubscriptionModuleInteracting {
        ManageSubscriptionModuleInteractor(
            passwordInteractor: InteractorFactory.shared.passwordInteractor(),
            webBrowsersInteractor: InteractorFactory.shared.webBrowsersInteractor(),
            paymentStatusInteractor: InteractorFactory.shared.paymentStatusInteractor(),
            systemInteractor: InteractorFactory.shared.systemInteractor()
        )
    }
    
    func viewLogsModuleInteractor() -> ViewLogsModuleInteracting {
        ViewLogsModuleInteractor(
            debugInteractor: InteractorFactory.shared.debugInteractor()
        )
    }
    
    func quickSetupModuleInteractor() -> QuickSetupModuleInteracting {
        QuickSetupModuleInteractor(
            autoFillStatusInteractor: InteractorFactory.shared.autoFillStatusInteractor(),
            cloudSyncInteractor: InteractorFactory.shared.cloudSyncInteractor(),
            configInteractor: InteractorFactory.shared.configInteractor(),
            quickSetupInteractor: InteractorFactory.shared.quickSetupInteractor()
        )
    }
    
    func manageTagsModuleInteractor() -> ManageTagsModuleInteracting {
        ManageTagsModuleInteractor(
            tagInteractor: InteractorFactory.shared.tagInteractor(),
            passwordInteractor: InteractorFactory.shared.passwordInteractor(),
            syncChangeTriggerInteractor: InteractorFactory.shared.syncChangeTriggerInteractor(callsChange: false)
        )
    }
}
