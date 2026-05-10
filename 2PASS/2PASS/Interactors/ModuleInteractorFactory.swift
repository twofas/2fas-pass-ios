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
            syncTriggerInteractor: InteractorFactory.shared.backupSyncTriggerInteractor(),
            appNotificationsInteractor: InteractorFactory.shared.appNotificationsInteractor(),
            timeVerificationInteractor: InteractorFactory.shared.timeVerificationInteractor(),
            paymentHandlingInteractor: InteractorFactory.shared.paymentHandlingInteractor(),
            onboardingInteractor: InteractorFactory.shared.onboardingInteractor(),
            updateAppPromptInteractor: InteractorFactory.shared.updateAppPromptInteractor(),
            credentialExchangeImporter: InteractorFactory.shared.credentialExchangeImporter(),
            configInteractor: InteractorFactory.shared.configInteractor(),
            shareLinkInteractor: InteractorFactory.shared.shareInteractor(),
            backupSyncInstaller: InteractorFactory.shared.backupSyncSetupInteractor()
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
            configsInteractor: InteractorFactory.shared.backupSyncConfigsInteractor(),
            autoFillStatusInteractor: InteractorFactory.shared.autoFillStatusInteractor(),
            pushNotificationsInteractor: InteractorFactory.shared.pushNotificationsPermissionInteractor(),
            paymentStatusInteractor: InteractorFactory.shared.paymentStatusInteractor()
        )
    }
    
    func trashInteractor() -> TrashModuleInteracting {
        TrashModuleInteractor(
            itemsInteractor: InteractorFactory.shared.itemsInteractor(),
            fileIconInteractor: InteractorFactory.shared.fileIconInteractor(),
            syncTriggerInteractor: InteractorFactory.shared.backupSyncTriggerInteractor(),
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
            itemsInteractor: InteractorFactory.shared.itemsInteractor(),
            biometryInteractor: InteractorFactory.shared.biometryInteractor(),
            loginInteractor: InteractorFactory.shared.loginInteractor(),
            protectionInteractor: InteractorFactory.shared.protectionInteractor(),
            paymentStatusInteractor: InteractorFactory.shared.paymentStatusInteractor()
        )
    }
    
    func backupImportImportingModuleInteractor(input: BackupImportInput) -> BackupImportImportingModuleInteracting {
        BackupImportImportingModuleInteractor(
            itemsImportInteractor: InteractorFactory.shared.itemsImportInteractor(),
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
            loginInteractor: InteractorFactory.shared.loginInteractor(),
            protectionInteractor: InteractorFactory.shared.protectionInteractor()
        )
    }
    
    func vaultRecoveryCheckModuleInteractor(url: URL) -> VaultRecoveryCheckModuleInteracting {
        VaultRecoveryCheckModuleInteractor(
            importInteractor: InteractorFactory.shared.backupImportInteractor(),
            url: url
        )
    }
    
    @MainActor
    func backupConfigsModuleInteractor() -> BackupConfigsModuleInteracting {
        BackupConfigsModuleInteractor(
            configsInteractor: InteractorFactory.shared.backupSyncConfigsInteractor(),
            syncTriggerInteractor: InteractorFactory.shared.backupSyncTriggerInteractor(),
            uriInteractor: InteractorFactory.shared.uriInteractor()
        )
    }

    @MainActor
    func backupWebDAVConfigModuleInteractor(configID: UUID?) -> BackupWebDAVConfigModuleInteracting {
        BackupWebDAVConfigModuleInteractor(
            configsInteractor: InteractorFactory.shared.backupSyncConfigsInteractor(),
            syncTriggerInteractor: InteractorFactory.shared.backupSyncTriggerInteractor(),
            uriInteractor: InteractorFactory.shared.uriInteractor(),
            configID: configID
        )
    }

    @MainActor
    func backupS3ConfigModuleInteractor(configID: UUID?) -> BackupS3ConfigModuleInteracting {
        BackupS3ConfigModuleInteractor(
            configsInteractor: InteractorFactory.shared.backupSyncConfigsInteractor(),
            syncTriggerInteractor: InteractorFactory.shared.backupSyncTriggerInteractor(),
            uriInteractor: InteractorFactory.shared.uriInteractor(),
            configID: configID
        )
    }
    
    func mainModuleInteracting() -> MainModuleInteracting {
        MainModuleInteractor(
            syncTriggerInteractor: InteractorFactory.shared.backupSyncTriggerInteractor(),
            configsInteractor: InteractorFactory.shared.backupSyncConfigsInteractor(),
            systemInteractor: InteractorFactory.shared.systemInteractor(),
            quickSetupInteractor: InteractorFactory.shared.quickSetupInteractor(),
            loginInteractor: InteractorFactory.shared.loginInteractor()
        )
    }
    
    func generateContentModuleInteractor() -> GenerateContentModuleInteracting {
        GenerateContentModuleInteractor(
            debugInteractor: InteractorFactory.shared.debugInteractor(),
            syncTriggerInteractor: InteractorFactory.shared.backupSyncTriggerInteractor()
        )
    }
    
    func vaultRecoveryRecoverModuleInteractor(kind: VaultRecoveryRecoverKind) -> VaultRecoveryRecoverModuleInteracting {
        VaultRecoveryRecoverModuleInteractor(
            kind: kind,
            itemsImportInteractor: InteractorFactory.shared.itemsImportInteractor(),
            startupInteractor: InteractorFactory.shared.startupInteractor(),
            importInteractor: InteractorFactory.shared.importInteractor(),
            onboardingInteractor: InteractorFactory.shared.onboardingInteractor(),
            syncTriggerInteractor: InteractorFactory.shared.backupSyncTriggerInteractor(),
            configsInteractor: InteractorFactory.shared.backupSyncConfigsInteractor()
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
            importInteractor: InteractorFactory.shared.importInteractor(),
            recoveryKitScanInteractor: InteractorFactory.shared.recoveryKitScanInteractor()
        )
    }
    
    func vaultRecoveryCameraModuleInteractor() -> VaultRecoveryCameraModuleInteracting {
        VaultRecoveryCameraModuleInteractor(
            cameraPermissionInteractor: InteractorFactory.shared.cameraPermissionsInteractor(),
            recoveryKitScanner: InteractorFactory.shared.recoveryKitScanCameraInteractor()
        )
    }
    
    func vaultRecoveryWebDAVModuleInteractor() -> VaultRecoveryWebDAVModuleInteracting {
        VaultRecoveryWebDAVModuleInteractor(
            recoveryInteractor: InteractorFactory.shared.backupSyncRecoveryInteractor(),
            uriInteractor: InteractorFactory.shared.uriInteractor()
        )
    }

    func vaultRecoverySelectWebDAVIndexModuleInteractor() -> VaultRecoverySelectWebDAVIndexModuleInteracting {
        VaultRecoverySelectWebDAVIndexModuleInteractor(
            recoveryInteractor: InteractorFactory.shared.backupSyncRecoveryInteractor()
        )
    }

    @MainActor
    func vaultRecoveryS3ModuleInteractor() -> VaultRecoveryS3ModuleInteracting {
        VaultRecoveryS3ModuleInteractor(
            recoveryInteractor: InteractorFactory.shared.backupSyncRecoveryInteractor(),
            uriInteractor: InteractorFactory.shared.uriInteractor()
        )
    }

    func vaultRecoverySelectS3IndexModuleInteractor() -> VaultRecoverySelectS3IndexModuleInteracting {
        VaultRecoverySelectS3IndexModuleInteractor(
            recoveryInteractor: InteractorFactory.shared.backupSyncRecoveryInteractor()
        )
    }
    
    func generateSecretKeyModuleInteractor() -> GenerateSecretKeyModuleInteracting {
        GenerateSecretKeyModuleInteractor(
            startupInteractor: InteractorFactory.shared.startupInteractor()
        )
    }
    
    func vaultRecoveryiCloudVaultSelectionModuleInteractor() -> VaultRecoveryiCloudVaultSelectionModuleInteracting {
        VaultRecoveryiCloudVaultSelectionModuleInteractor(
            recoveryInteractor: InteractorFactory.shared.backupSyncRecoveryInteractor()
        )
    }
    
    func setupCompleteModuleInteractor() -> SetupCompleteModuleInteracting {
        SetupCompleteModuleInteractor(
            onboardingInteractor: InteractorFactory.shared.onboardingInteractor()
        )
    }
    
    func customizationModuleInteractor() -> CustomizationModuleInteracting {
        CustomizationModuleInteractor(
            configInteractor: InteractorFactory.shared.configInteractor(),
            syncTriggerInteractor: InteractorFactory.shared.backupSyncTriggerInteractor()
        )
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
            itemsInteractor: InteractorFactory.shared.itemsInteractor(),
            appNotificationsInteractor: InteractorFactory.shared.appNotificationsInteractor(),
            paymentStatusInteractor: InteractorFactory.shared.paymentStatusInteractor(),
            paymentCardUtilityInteractor: InteractorFactory.shared.paymentCardUtilityInteractor(),
            syncTriggerInteractor: InteractorFactory.shared.backupSyncTriggerInteractor()
        )
    }
    
    func pushNotificationsModuleInteractor() -> PushNotificationsModuleInteracting {
        PushNotificationsModuleInteractor(pushNotificationsPermissionInteractor: InteractorFactory.shared.pushNotificationsPermissionInteractor())
    }
    
    func transferItemsInstructionsModuleInteractor(service: ExternalService) -> TransferItemsInstructionsModuleInteracting {
        TransferItemsInstructionsModuleInteractor(service: service, externalServiceImportInteractor: InteractorFactory.shared.externalServiceImportInteractor())
    }
    
    func transferItemsImportingModuleInteractor(service: ExternalService, result: ExternalServiceImportResult) -> TransferItemsImportingModuleInteracting {
        TransferItemsImportingModuleInteractor(
            service: service,
            result: result,
            itemsImportInteractor: InteractorFactory.shared.itemsImportInteractor()
        )
    }
    
    @available(iOS 26.0, *)
    func credentialExchangeExportModuleInteractor() -> CredentialExchangeExportModuleInteracting {
        CredentialExchangeExportModuleInteractor(
            exporter: InteractorFactory.shared.credentialExchangeExporter(),
            itemsInteractor: InteractorFactory.shared.itemsInteractor()
        )
    }

    @available(iOS 26.0, *)
    func credentialExchangeImportModuleInteractor() -> CredentialExchangeImportModuleInteracting {
        CredentialExchangeImportModuleInteractor(
            credentialExchangeImporter: InteractorFactory.shared.credentialExchangeImporter()
        )
    }

    @available(iOS 26.0, *)
    func credentialExchangePerformImportModuleInteractor() -> CredentialExchangePerformImportModuleInteracting {
        CredentialExchangePerformImportModuleInteractor(
            itemsImportInteractor: InteractorFactory.shared.itemsImportInteractor()
        )
    }

    func transferItemsServicesListInteractor() -> TransferItemsServicesListInteracting {
        TransferItemsServicesListInteractor(
            itemsInteractor: InteractorFactory.shared.itemsInteractor(),
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
            itemsInteractor: InteractorFactory.shared.itemsInteractor(),
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
            configsInteractor: InteractorFactory.shared.backupSyncConfigsInteractor(),
            syncTriggerInteractor: InteractorFactory.shared.backupSyncTriggerInteractor(),
            configInteractor: InteractorFactory.shared.configInteractor(),
            quickSetupInteractor: InteractorFactory.shared.quickSetupInteractor()
        )
    }
    
    func manageTagsModuleInteractor() -> ManageTagsModuleInteracting {
        ManageTagsModuleInteractor(
            tagInteractor: InteractorFactory.shared.tagInteractor(),
            itemsInteractor: InteractorFactory.shared.itemsInteractor(),
            syncTriggerInteractor: InteractorFactory.shared.backupSyncTriggerInteractor()
        )
    }
}
