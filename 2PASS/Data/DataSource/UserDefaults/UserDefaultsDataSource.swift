// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

protocol UserDefaultsDataSource: AnyObject {
    var deviceID: UUID? { get }
    func setDeviceID(_ deviceID: UUID)
    func clearDeviceID()
    
    func setCrashlyticsDisabled(_ disabled: Bool)
    var isCrashlyticsDisabled: Bool { get }
    
    func saveDateOfFirstRun(_ date: Date)
    var dateOfFirstRun: Date? { get }
    
    func setAppLockAttempts(_ value: AppLockAttempts)
    var appLockAttempts: AppLockAttempts? { get }
    
    func setAppLockBlockTime(_ value: AppLockBlockTime)
    var appLockBlockTime: AppLockBlockTime? { get }
    func clearAppLockBlockTime()
    
    func setLockAppUntil(date: Date)
    var lockAppUntil: Date? { get }
    
    func clearLockAppUntil()
    
    func setSortType(_ sortType: SortType)
    var sortType: SortType? { get }
    
    func setActiveSearchEnabled(_ enabled: Bool)
    var isActiveSearchEnabled: Bool { get }
    
    var incorrectLoginCountAttemp: Int { get }
    func setIncorrectLoginCountAttempt(_ count: Int)
    func clearIncorrectLoginCountAttempt()
    
    var incorrectBiometryCountAttemp: Int { get }
    func setIncorrectBiometryCountAttempt(_ count: Int)
    func clearIncorrectBiometryCountAttempt()
    
    var currentDefaultProtectionLevel: ItemProtectionLevel { get }
    func setDefaultProtectionLevel(_ value: ItemProtectionLevel)
    
    var passwordGeneratorConfig: Data? { get }
    func setPasswordGeneratorConfig(_ data: Data)

    var shareLinkConfig: Data? { get }
    func setShareLinkConfig(_ data: Data)
    
    func migrateLegacyValuesToSharedDefaults()
    
    var backupConfigsBlob: Data? { get }
    func saveBackupConfigsBlob(_ data: Data)
    func clearBackupConfigsBlob()

    /// Plaintext per-config last-successful-sync timestamps. Not encrypted: timestamps aren't
    /// sensitive, and dropping the encryption removes the `appKey` dependency so reads work in
    /// any auth state.
    var lastSyncDatesBlob: Data? { get }
    func saveLastSyncDatesBlob(_ data: Data)
    func clearLastSyncDatesBlob()

    /// Legacy single-config blob, retained read-only so migration code can hoist a pre-existing
    /// WebDAV config into the new `backupConfigsBlob` list and then clear this slot.
    var legacyWebDAVSavedConfig: Data? { get }
    func clearLegacyWebDAVSavedConfig()

    /// Legacy iCloud-enabled flag, retained read-only so migration code can detect a
    /// pre-multi-config user who had iCloud sync turned on. Backed by the same UserDefaults
    /// key the Backup module's `ConstStorage.cloudEnabled` writes to
    /// (`Backup/Cloud/ConstStorage.swift`, key `"KeyCloudEnabled"`). No clear pair: the
    /// runtime `CloudHandler` in 1.9.0 still uses the same key as its enabled-state, so
    /// migration reads it but never mutates it.
    var legacyCloudEnabled: Bool { get }
    
    var webDAVIsConnected: Bool { get }
    func webDAVSetIsConnected(_ isConnected: Bool)
    func webDAVClearIsConnected()
    
    var webDAVState: Data? { get }
    func webDAVSetState(_ state: Data)
    func webDAVClearState()
    
    var webDAVLastSync: Data? { get }
    func webDAVSetLastSync(_ lastSync: Data)
    func webDAVClearLastSync()
    
    var webDAVHasLocalChanges: Bool { get }
    func webDAVSetHasLocalChanges()
    func webDAVClearHasLocalChanges()
    
    var isOnboardingCompleted: Bool { get }
    func onboardingCompleted(_ complete: Bool)
    func clearOnboardingCompleted()
    
    var isConnectOnboardingCompleted: Bool { get }
    func connectOnboardingCompleted(_ complete: Bool)
    func clearConnectOnboardingCompleted()
    
    var defaultPassswordListAction: PasswordListAction { get }
    func setDefaultPassswordListAction(_ action: PasswordListAction)

    var defaultURIMatchRule: PasswordURI.Match { get }
    func setDefaultURIMatchRule(_ rule: PasswordURI.Match)
    
    var webDAVWriteDecryptedCopy: Bool { get }
    func webDAVSetWriteDecryptedCopy(_ writeDecryptedCopy: Bool)

    var timeOffset: TimeInterval { get }
    func setTimeOffset(_ offset: TimeInterval)
    
    var requestedForBiometryToLogin: Bool { get }
    func setRequestedForBiometryToLogin(_ requested: Bool)
    
    var vaultOverrideAwaitingConfigIDs: Set<BackupConfig.ID> { get }
    func saveVaultOverrideAwaitingConfigIDs(_ ids: Set<BackupConfig.ID>)

    var deviceRegistrationAwaitingConfigIDs: Set<BackupConfig.ID> { get }
    func saveDeviceRegistrationAwaitingConfigIDs(_ ids: Set<BackupConfig.ID>)
    
    var debugSubscriptionPlan: SubscriptionPlan? { get }
    func setDebugSubscriptionPlan(_ plan: SubscriptionPlan)
    func clearDebugSubscriptionPlan()
    
    var lastKnownAppVersion: String? { get }
    func setLastKnownAppVersion(_ version: String)
    
    var lastKnownSubscriptionPlan: SubscriptionPlan? { get }
    func setLastKnownSubscriptionPlan(_ plan: SubscriptionPlan)
    
    var shouldShowQuickSetup: Bool { get }
    func setShouldShowQuickSetup(_ value: Bool)
    
    var lastAppUpdatePromptDate: Date? { get }
    func setLastAppUpdatePromptDate(_ date: Date)
    func clearLastAppUpdatePromptDate()

    var screenCaptureAllowedUntil: Date? { get }
    func setScreenCaptureAllowedUntil(_ date: Date)
    func clearScreenCaptureAllowedUntil()

    var deviceName: String? { get }
    func setDeviceName(_ name: String)
}
