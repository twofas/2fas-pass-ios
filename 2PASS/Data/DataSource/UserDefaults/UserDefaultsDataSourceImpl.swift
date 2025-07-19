// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

final class UserDefaultsDataSourceImpl {
    private enum Keys: String, CaseIterable {
        case deviceID
        case appLockAttempts
        case appLockBlockTime
        case sortType
        case lockAppUntil
        case introductionWasShown
        case crashlyticsDisabled
        case activeSearchEnabled
        case dateOfFirstRun
        case biometryEnabled
        case masterKeySalt
        case masterKeyTemplate
        case incorrectLoginCountAttemp
        case incorrectBiometryCountAttemp
        case defaultProtectionLevel
        case passwordGeneratorConfig
        case webDAVSavedConfig
        case webDAVIsConnected
        case webDAVState
        case webDAVLastSync
        case webDAVHasLocalChanges
        case cloudLastSuccessSync
        case onboardingCompleted
        case connectOnboardingCompleted
        case defaultPasswordListAction
        case webDAVWriteDecryptedCopy
        case timeOffset
        case requestedForBiometryToLogin
        case debugSubscriptionPlan
        case debugSubscriptionPlanExpireDate
        case webDAVAwaitsVaultOverrideAfterPasswordChange
        case lastKnownAppVersion
    }
    
    private let userDefaults = UserDefaults()
    private let sharedDefaults = UserDefaults(suiteName: Config.suiteName)!
}

extension UserDefaultsDataSourceImpl: UserDefaultsDataSource {
    var deviceID: UUID? {
        guard let uuidString = sharedDefaults.string(forKey: Keys.deviceID.rawValue) else {
            return nil
        }
        return UUID(uuidString: uuidString)
    }
    
    func setDeviceID(_ deviceID: UUID) {
        sharedDefaults.set(deviceID.uuidString, forKey: Keys.deviceID.rawValue)
        sharedDefaults.synchronize()
    }
    
    func clearDeviceID() {
        sharedDefaults.set(nil, forKey: Keys.deviceID.rawValue)
        sharedDefaults.synchronize()
    }
    
    func setIntroductionAsShown() {
        userDefaults.set(true, forKey: Keys.introductionWasShown.rawValue)
        userDefaults.synchronize()
    }
    
    var wasIntroductionShown: Bool {
        userDefaults.bool(forKey: Keys.introductionWasShown.rawValue)
    }
    
    func setCrashlyticsDisabled(_ disabled: Bool) {
        userDefaults.set(disabled, forKey: Keys.crashlyticsDisabled.rawValue)
        userDefaults.synchronize()
    }
    
    var isCrashlyticsDisabled: Bool {
        userDefaults.bool(forKey: Keys.crashlyticsDisabled.rawValue)
    }
    
    func saveDateOfFirstRun(_ date: Date) {
        userDefaults.set(date.timeIntervalSince1970, forKey: Keys.dateOfFirstRun.rawValue)
        userDefaults.synchronize()
    }
    
    var dateOfFirstRun: Date? {
        guard userDefaults.object(forKey: Keys.dateOfFirstRun.rawValue) != nil else { return nil }
        let value = userDefaults.double(forKey: Keys.dateOfFirstRun.rawValue)
        let date = Date(timeIntervalSince1970: value)
        return date
    }
    
    func setAppLockAttempts(_ value: AppLockAttempts) {
        userDefaults.set(value.rawValue, forKey: Keys.appLockAttempts.rawValue)
        userDefaults.synchronize()
    }
    
    var appLockAttempts: AppLockAttempts? {
        guard let value = userDefaults.string(forKey: Keys.appLockAttempts.rawValue) else { return nil }
        return AppLockAttempts(rawValue: value)
    }
    
    func clearAppLockBlockTime() {
        userDefaults.set(nil, forKey: Keys.appLockBlockTime.rawValue)
        userDefaults.synchronize()
    }
    
    func setAppLockBlockTime(_ value: AppLockBlockTime) {
        userDefaults.set(value.rawValue, forKey: Keys.appLockBlockTime.rawValue)
        userDefaults.synchronize()
    }
    
    var appLockBlockTime: AppLockBlockTime? {
        guard let value = userDefaults.string(forKey: Keys.appLockBlockTime.rawValue) else { return nil }
        return AppLockBlockTime(rawValue: value)
    }
    
    func setLockAppUntil(date: Date) {
        userDefaults.set(date.timeIntervalSince1970, forKey: Keys.lockAppUntil.rawValue)
        userDefaults.synchronize()
    }
    
    var lockAppUntil: Date? {
        guard userDefaults.object(forKey: Keys.lockAppUntil.rawValue) != nil else { return nil }
        let value = userDefaults.double(forKey: Keys.lockAppUntil.rawValue)
        let date = Date(timeIntervalSince1970: value)
        return date
    }
    
    func clearLockAppUntil() {
        userDefaults.set(nil, forKey: Keys.lockAppUntil.rawValue)
        userDefaults.synchronize()
    }
    
    func setSortType(_ sortType: SortType) {
        userDefaults.set(sortType.rawValue, forKey: Keys.sortType.rawValue)
        userDefaults.synchronize()
    }
    
    var sortType: SortType? {
        guard let value = userDefaults.string(forKey: Keys.sortType.rawValue) else { return nil }
        return SortType(rawValue: value)
    }
    
    func setActiveSearchEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: Keys.activeSearchEnabled.rawValue)
        userDefaults.synchronize()
    }
    
    var isActiveSearchEnabled: Bool {
        userDefaults.bool(forKey: Keys.activeSearchEnabled.rawValue)
    }
    
    var incorrectLoginCountAttemp: Int {
        userDefaults.integer(forKey: Keys.incorrectLoginCountAttemp.rawValue)
    }
    
    func setIncorrectLoginCountAttempt(_ count: Int) {
        userDefaults.setValue(count, forKey: Keys.incorrectLoginCountAttemp.rawValue)
        userDefaults.synchronize()
    }
    
    func clearIncorrectLoginCountAttempt() {
        userDefaults.setValue(nil, forKey: Keys.incorrectLoginCountAttemp.rawValue)
        userDefaults.synchronize()
    }
    
    var incorrectBiometryCountAttemp: Int {
        userDefaults.integer(forKey: Keys.incorrectBiometryCountAttemp.rawValue)
    }
    
    func setIncorrectBiometryCountAttempt(_ count: Int) {
        userDefaults.setValue(count, forKey: Keys.incorrectBiometryCountAttemp.rawValue)
        userDefaults.synchronize()
    }
    
    func clearIncorrectBiometryCountAttempt() {
        userDefaults.setValue(nil, forKey: Keys.incorrectBiometryCountAttemp.rawValue)
        userDefaults.synchronize()
    }
    
    var currentDefaultProtectionLevel: ItemProtectionLevel {
        guard let string = userDefaults.string(forKey: Keys.defaultProtectionLevel.rawValue),
              let value = ItemProtectionLevel(rawValue: string)
        else {
            return ItemProtectionLevel.default
        }
        return value
    }
    
    func setDefaultProtectionLevel(_ value: ItemProtectionLevel) {
        userDefaults.setValue(value.rawValue, forKey: Keys.defaultProtectionLevel.rawValue)
        userDefaults.synchronize()
    }
    
    var passwordGeneratorConfig: Data? {
        userDefaults.data(forKey: Keys.passwordGeneratorConfig.rawValue)
    }
    
    func setPasswordGeneratorConfig(_ data: Data) {
        userDefaults.setValue(data, forKey: Keys.passwordGeneratorConfig.rawValue)
        userDefaults.synchronize()
    }
    
    var webDAVSavedConfig: Data? {
        userDefaults.data(forKey: Keys.webDAVSavedConfig.rawValue)
     }
    
    func saveWebDAVSavedConfig(_ config: Data) {
        userDefaults.setValue(config, forKey: Keys.webDAVSavedConfig.rawValue)
        userDefaults.synchronize()
    }
    
    func clearWebDAVConfig() {
        userDefaults.setValue(nil, forKey: Keys.webDAVSavedConfig.rawValue)
        userDefaults.synchronize()
    }
    
    var webDAVIsConnected: Bool {
        userDefaults.bool(forKey: Keys.webDAVIsConnected.rawValue)
    }
    
    func webDAVSetIsConnected(_ isConnected: Bool) {
        userDefaults.setValue(isConnected, forKey: Keys.webDAVIsConnected.rawValue)
        userDefaults.synchronize()
    }
    
    func webDAVClearIsConnected() {
        userDefaults.setValue(false, forKey: Keys.webDAVIsConnected.rawValue)
        userDefaults.synchronize()
    }
    
    var webDAVState: Data? {
        userDefaults.data(forKey: Keys.webDAVState.rawValue)
    }
    
    func webDAVSetState(_ state: Data) {
        userDefaults.setValue(state, forKey: Keys.webDAVState.rawValue)
        userDefaults.synchronize()
    }
    
    func webDAVClearState() {
        userDefaults.setValue(nil, forKey: Keys.webDAVState.rawValue)
        userDefaults.synchronize()
    }
    
    var webDAVLastSync: Data? {
        userDefaults.data(forKey: Keys.webDAVLastSync.rawValue)
    }
    
    func webDAVSetLastSync(_ lastSync: Data) {
        userDefaults.setValue(lastSync, forKey: Keys.webDAVLastSync.rawValue)
        userDefaults.synchronize()
    }
    
    func webDAVClearLastSync() {
        userDefaults.setValue(nil, forKey: Keys.webDAVLastSync.rawValue)
        userDefaults.synchronize()
    }

    var webDAVHasLocalChanges: Bool {
        userDefaults.bool(forKey: Keys.webDAVHasLocalChanges.rawValue)
    }
    
    func webDAVSetHasLocalChanges() {
        userDefaults.setValue(true, forKey: Keys.webDAVHasLocalChanges.rawValue)
        userDefaults.synchronize()
    }
    
    func webDAVClearHasLocalChanges() {
        userDefaults.setValue(false, forKey: Keys.webDAVHasLocalChanges.rawValue)
        userDefaults.synchronize()
    }
    
    var isOnboardingCompleted: Bool {
        sharedDefaults.bool(forKey: Keys.onboardingCompleted.rawValue)
    }
    
    func onboardingCompleted(_ completed: Bool) {
        sharedDefaults.set(completed, forKey: Keys.onboardingCompleted.rawValue)
        sharedDefaults.synchronize()
    }
    
    func clearOnboardingCompleted() {
        sharedDefaults.setValue(nil, forKey: Keys.onboardingCompleted.rawValue)
    }
    
    var isConnectOnboardingCompleted: Bool {
        userDefaults.bool(forKey: Keys.connectOnboardingCompleted.rawValue)
    }
    
    func connectOnboardingCompleted(_ complete: Bool) {
        userDefaults.set(complete, forKey: Keys.connectOnboardingCompleted.rawValue)
        userDefaults.synchronize()
    }
    
    func clearConnectOnboardingCompleted() {
        userDefaults.setValue(nil, forKey: Keys.connectOnboardingCompleted.rawValue)
    }
    
    var defaultPassswordListAction: PasswordListAction {
        let value = userDefaults.integer(forKey: Keys.defaultPasswordListAction.rawValue)
        return PasswordListAction(rawValue: value) ?? .viewDetails
    }
    
    func setDefaultPassswordListAction(_ action: PasswordListAction) {
        userDefaults.set(action.rawValue, forKey: Keys.defaultPasswordListAction.rawValue)
        userDefaults.synchronize()
    }
    
    var lastSuccessCloudSyncDate: Date? {
        userDefaults.object(forKey: Keys.cloudLastSuccessSync.rawValue) as? Date
    }
    
    func setLastSuccessCloudSyncDate(_ date: Date) {
        userDefaults.set(date, forKey: Keys.cloudLastSuccessSync.rawValue)
        userDefaults.synchronize()
    }
    
    func clearLastSuccessCloudSyncDate() {
        userDefaults.set(nil, forKey: Keys.cloudLastSuccessSync.rawValue)
        userDefaults.synchronize()
    }
    
    var webDAVWriteDecryptedCopy: Bool {
        userDefaults.bool(forKey: Keys.webDAVWriteDecryptedCopy.rawValue)
    }
    
    func webDAVSetWriteDecryptedCopy(_ writeDecryptedCopy: Bool) {
        userDefaults.set(writeDecryptedCopy, forKey: Keys.webDAVWriteDecryptedCopy.rawValue)
        userDefaults.synchronize()
    }

    var timeOffset: TimeInterval {
        userDefaults.double(forKey: Keys.timeOffset.rawValue)
    }
    
    func setTimeOffset(_ offset: TimeInterval) {
        userDefaults.set(offset, forKey: Keys.timeOffset.rawValue)
        userDefaults.synchronize()
    }
    
    var requestedForBiometryToLogin: Bool {
        userDefaults.bool(forKey: Keys.requestedForBiometryToLogin.rawValue)
    }
    
    func setRequestedForBiometryToLogin(_ requested: Bool) {
        userDefaults.set(requested, forKey: Keys.requestedForBiometryToLogin.rawValue)
        userDefaults.synchronize()
    }
    
    var debugSubscriptionPlan: SubscriptionPlan? {
        guard let value = userDefaults.string(forKey: Keys.debugSubscriptionPlan.rawValue) else {
            return nil
        }
        
        switch SubscriptionPlanType(rawValue: value) {
        case .free:
            return SubscriptionPlan.free
        case .premium:
            let expireDate = Date(timeIntervalSinceReferenceDate: userDefaults.double(forKey: Keys.debugSubscriptionPlanExpireDate.rawValue))
            return SubscriptionPlan(planType: .premium, paymentInfo: .init(expirationDate: expireDate, willRenew: true))
        default:
            return nil
        }
    }
    
    var webDAVAwaitsVaultOverrideAfterPasswordChange: Bool {
        userDefaults.bool(forKey: Keys.webDAVAwaitsVaultOverrideAfterPasswordChange.rawValue)
    }
    
    func setWebDAVAwaitsVaultOverrideAfterPasswordChange(_ value: Bool) {
        userDefaults.set(value, forKey: Keys.webDAVAwaitsVaultOverrideAfterPasswordChange.rawValue)
        userDefaults.synchronize()
    }
    
    func setDebugSubscriptionPlan(_ plan: SubscriptionPlan) {
        userDefaults.set(plan.planType.rawValue, forKey: Keys.debugSubscriptionPlan.rawValue)
        userDefaults.set(plan.expirationDate?.timeIntervalSinceReferenceDate, forKey: Keys.debugSubscriptionPlanExpireDate.rawValue)
    }
    
    func clearDebugSubscriptionPlan() {
        userDefaults.set(nil, forKey: Keys.debugSubscriptionPlan.rawValue)
        userDefaults.set(nil, forKey: Keys.debugSubscriptionPlanExpireDate.rawValue)
    }
    
    var lastKnownAppVersion: String? {
        userDefaults.string(forKey: Keys.lastKnownAppVersion.rawValue)
    }
    
    func setLastKnownAppVersion(_ version: String) {
        userDefaults.set(version, forKey: Keys.lastKnownAppVersion.rawValue)
        userDefaults.synchronize()
    }
}
