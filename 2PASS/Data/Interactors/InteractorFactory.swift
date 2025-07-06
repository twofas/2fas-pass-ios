// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public final class InteractorFactory {
    public static let shared = InteractorFactory()
    
    public func rootInteractor() -> RootInteracting {
        RootInteractor(
            mainRepository: MainRepositoryImpl.shared,
            cameraInteractor: cameraPermissionsInteractor(),
            securityInteractor: securityInteractor()
        )
    }
    
    public func cameraPermissionsInteractor() -> CameraPermissionInteracting {
        CameraPermissionInteractor(mainRepository: MainRepositoryImpl.shared)
    }
    
    public func protectionInteractor() -> ProtectionInteracting {
        ProtectionInteractor(
            mainRepository: MainRepositoryImpl.shared,
            storageInteractor: storageInteractor()
        )
    }
    
    public func securityInteractor() -> SecurityInteracting {
        SecurityInteractor(
            mainRepository: MainRepositoryImpl.shared,
            storageInteractor: storageInteractor(),
            protectionInteractor: protectionInteractor()
        )
    }
    
    public func appStateInteractor() -> AppStateInteracting {
        AppStateInteractor(mainRepository: MainRepositoryImpl.shared)
    }
    
    public func passwordInteractor() -> PasswordInteracting {
        PasswordInteractor(
            mainRepository: MainRepositoryImpl.shared,
            protectionInteractor: protectionInteractor(),
            uriInteractor: uriInteractor(),
            deletedItemsInteractor: deletedItemsInteractor()
        )
    }
    
    public func systemInteractor() -> SystemInteracting {
        SystemInteractor(mainRepository: MainRepositoryImpl.shared)
    }
    
    public func configInteractor() -> ConfigInteracting {
        ConfigInteractor(mainRepository: MainRepositoryImpl.shared)
    }
    
    public func fileIconInteractor() -> FileIconInteracting {
        FileIconInteractor(mainRepository: MainRepositoryImpl.shared)
    }
    
    public func uriInteractor() -> URIInteracting {
        URIInteractor(mainRepository: MainRepositoryImpl.shared)
    }
    
    func storageInteractor() -> StorageInteracting {
        StorageInteractor(
            mainRepository: MainRepositoryImpl.shared,
            autoFillInteractor: autoFillCredentialsInteractor()
        )
    }
    
    public func startupInteractor() -> StartupInteracting {
        StartupInteractor(
            protectionInteractor: protectionInteractor(),
            storageInteractor: storageInteractor(),
            biometryInteractor: biometryInteractor(),
            onboardingInteractor: onboardingInteractor()
        )
    }
    
    public func loginInteractor() -> LoginInteracting {
        LoginInteractor(
            mainRepository: MainRepositoryImpl.shared,
            protectionInteractor: protectionInteractor(),
            securityInteractor: securityInteractor(),
            storageInteractor: storageInteractor(),
            biometryInteractor: biometryInteractor()
        )
    }
    
    public func biometryInteractor() -> BiometryInteracting {
        BiometryInteractor(mainRepository: MainRepositoryImpl.shared)
    }
    
    public func debugInteractor() -> DebugInteracting {
        DebugInteractor(
            mainRepository: MainRepositoryImpl.shared,
            passwordInteractor: InteractorFactory.shared.passwordInteractor()
        )
    }
    
    public func importInteractor() -> ImportInteracting {
        ImportInteractor(
            mainRepository: MainRepositoryImpl.shared,
            passwordInteractor: passwordInteractor(),
            protectionInteractor: protectionInteractor(),
            uriInteractor: uriInteractor()
        )
    }
    
    public func exportInteractor() -> ExportInteracting {
        ExportInteractor(
            mainRepository: MainRepositoryImpl.shared,
            passwordInteractor: passwordInteractor(),
            uriInteractor: uriInteractor()
        )
    }
    
    public func recoveryKitInteractor(
        translations: RecoveryKitTranslations,
        pdfConfig: RecoveryKitPDFConfig
    ) -> RecoveryKitInteracting {
        RecoveryKitInteractor(
            translations: translations,
            pdfConfig: pdfConfig,
            mainRepository: MainRepositoryImpl.shared
        )
    }
    
    public func changePasswordInteractor() -> ChangePasswordInteracting {
        ChangePasswordInteractor(
            biometryInteractor: biometryInteractor(),
            passwordInteractor: passwordInteractor(),
            protectionInteractor: protectionInteractor(),
            syncChangeTriggerInteractor: syncChangeTriggerInteractor(callsChange: false)
        )
    }
    
    public func backupImportInteractor() -> BackupImportInteracting {
        BackupImportInteractor(importInteractor: importInteractor())
    }
    
    public func passwordImportInteractor() -> PasswordImportInteracting {
        PasswordImportInteractor(
            fileIconInteractor: fileIconInteractor(),
            passwordInteractor: passwordInteractor(),
            deletedItemsInteractor: deletedItemsInteractor(),
            syncChangeTriggerInteractor: syncChangeTriggerInteractor(callsChange: false),
            mainRepository: MainRepositoryImpl.shared
        )
    }
    
    public func webDAVBackupInteractor(ignoreDeviceId: Bool = false) -> WebDAVBackupInteracting {
        WebDAVBackupInteractor(
            ignoreDeviceId: ignoreDeviceId,
            mainRepository: MainRepositoryImpl.shared,
            backupImportInteractor: backupImportInteractor(),
            exportInteractor: exportInteractor(),
            webDAVStateInteractor: webDAVStateInteractor(),
            timerInteractor: timerInteractor(),
            syncInteractor: syncInteractor(),
            paymentStatusInteractor: paymentStatusInteractor()
        )
    }
    
    public func webDAVStateInteractor() -> WebDAVStateInteracting {
        WebDAVStateInteractor(mainRepository: MainRepositoryImpl.shared)
    }
    
    public func syncChangeTriggerInteractor(callsChange: Bool) -> SyncChangeTriggerInteracting {
        SyncChangeTriggerInteractor(mainRepository: MainRepositoryImpl.shared, callsChange: callsChange)
    }
    
    public func syncInteractor() -> SyncInteracting {
        SyncInteractor(
            passwordInteractor: passwordInteractor(),
            passwordImportInteractor: passwordImportInteractor(),
            deletedItemsInteractor: deletedItemsInteractor(),
            autoFillCredentialsInteractor: autoFillCredentialsInteractor()
        )
    }
    
    public func webDAVRecoveryInteractor() -> WebDAVRecoveryInteracting {
        WebDAVRecoveryInteractor(
            mainRepository: MainRepositoryImpl.shared,
            backupImportInteractor: backupImportInteractor()
        )
    }

    public func passwordGeneratorInteractor() -> PasswordGeneratorInteracting {
        PasswordGeneratorInteractor()
    }
    
    public func onboardingInteractor() -> OnboardingInteracting {
        OnboardingInteractor(mainRepository: MainRepositoryImpl.shared)
    }
    
    public func cloudSyncInteractor() -> CloudSyncInteracting {
        CloudSyncInteractor(
            cloudCacheStorage: CloudCacheStorageImpl(mainRepository: MainRepositoryImpl.shared),
            encryptionHandler: EncryptionHandlerImpl(
                mainRepository: MainRepositoryImpl.shared,
                passwordInteractor: passwordInteractor()
            ),
            localStorage: LocalStorageImpl(
                passwordInteractor: passwordInteractor(),
                deletedItemsInteractor: deletedItemsInteractor(),
                mainRepository: MainRepositoryImpl.shared
            ),
            mainRepository: MainRepositoryImpl.shared,
            paymentStatusInteractor: paymentStatusInteractor()
        )
    }
    
    public func cloudRecoveryInteracting() -> CloudRecoveryInteracting {
        CloudRecoveryInteractor(mainRepository: MainRepositoryImpl.shared)
    }
    
    public func autoFillCredentialsInteractor() -> AutoFillCredentialsInteracting {
        AutoFillCredentialsInteractor(mainRepository: MainRepositoryImpl.shared, uriInteractor: uriInteractor())
    }
    
    public func connectInteractor() -> ConnectInteracting {
        ConnectInteractor(
            mainRepository: MainRepositoryImpl.shared,
            passwordInteractor: passwordInteractor(),
            webBrowsersInteractor: webBrowsersInteractor(),
            connectExportInteractor: connectExportInteractor(),
            uriInteractor: uriInteractor(),
            paymentStatusInteractor: paymentStatusInteractor()
        )
    }
    
    public func connectSecurityIconInteractor() -> ConnectIdenticonInteracting {
        ConnectIdenticonInteractor()
    }
    
    public func autoFillStatusInteractor() -> AutoFillStatusInteracting {
        AutoFillStatusInteractor(mainRepository: MainRepositoryImpl.shared)
    }
    
    public func webBrowsersInteractor() -> WebBrowsersInteracting {
        WebBrowsersInteractor(mainRepository: MainRepositoryImpl.shared)
    }
    
    public func timeVerificationInteractor() -> TimeVerificationInteracting {
        TimeVerificationInteractor(mainRepository: MainRepositoryImpl.shared)
    }
    
    public func pushNotificationsPermissionInteractor() -> PushNotificationsPermissionInteracting {
        PushNotificationsPermissionInteractor(mainRepository: MainRepositoryImpl.shared)
    }
    
    public func externalServiceImportInteractor() -> ExternalServiceImportInteracting {
        ExternalServiceImportInteractor(mainRepository: MainRepositoryImpl.shared, uriInteractor: uriInteractor())
    }

    public func currentDateInteractor() -> CurrentDateInteracting {
        CurrentDateInteractor(mainRepository: MainRepositoryImpl.shared)
    }
    
    func connectExportInteractor() -> ConnectExportInteracting {
        ConnectExportInteractor(
            mainRepository: MainRepositoryImpl.shared,
            passwordInteractor: passwordInteractor(),
            uriInteractor: uriInteractor()
        )
    }
    
    public func appNotificationsInteractor() -> AppNotificationsInteracting {
        AppNotificationsInteractor(mainRepository: MainRepositoryImpl.shared, connectInteractor: connectInteractor())
    }
    
    public func paymentHandlingInteractor() -> PaymentHandlingInteracting {
        PaymentHandlingInteractor(mainRepository: MainRepositoryImpl.shared)
    }
    
    public func paymentStatusInteractor() -> PaymentStatusInteracting {
        PaymentStatusInteractor(mainRepository: MainRepositoryImpl.shared)
    }
    
    public func connectOnboardingInteractor() -> ConnectOnboardingInteracting {
        ConnectOnboardingInteractor(mainRepository: MainRepositoryImpl.shared)
    }
    
    public func deletedItemsInteractor() -> DeletedItemsInteracting {
        DeletedItemsInteractor(mainRepository: MainRepositoryImpl.shared)
    }
}

private extension InteractorFactory {
    func timerInteractor() -> TimerInteracting {
        TimerInteractor()
    }
}
