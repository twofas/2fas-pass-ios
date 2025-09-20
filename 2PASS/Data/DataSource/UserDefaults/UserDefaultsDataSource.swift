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
    
    var webDAVSavedConfig: Data? { get }
    func saveWebDAVSavedConfig(_ config: Data)
    func clearWebDAVConfig()
    
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
    
    var lastSuccessCloudSyncDate: Date? { get }
    func setLastSuccessCloudSyncDate(_ date: Date)
    func clearLastSuccessCloudSyncDate()
    
    var webDAVWriteDecryptedCopy: Bool { get }
    func webDAVSetWriteDecryptedCopy(_ writeDecryptedCopy: Bool)

    var timeOffset: TimeInterval { get }
    func setTimeOffset(_ offset: TimeInterval)
    
    var requestedForBiometryToLogin: Bool { get }
    func setRequestedForBiometryToLogin(_ requested: Bool)
    
    var webDAVAwaitsVaultOverrideAfterPasswordChange: Bool { get }
    func setWebDAVAwaitsVaultOverrideAfterPasswordChange(_ value: Bool)
    
    var debugSubscriptionPlan: SubscriptionPlan? { get }
    func setDebugSubscriptionPlan(_ plan: SubscriptionPlan)
    func clearDebugSubscriptionPlan()
    
    var lastKnownAppVersion: String? { get }
    func setLastKnownAppVersion(_ version: String)
    
    var lastKnownSubscriptionPlan: SubscriptionPlan? { get }
    func setLastKnownSubscriptionPlan(_ plan: SubscriptionPlan)
    
    var shouldShowQuickSetup: Bool { get }
    func setShouldShowQuickSetup(_ value: Bool)
}
