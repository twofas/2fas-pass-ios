// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

extension MainRepositoryImpl {
    var appLockAttempts: AppLockAttempts {
        userDefaultsDataSource.appLockAttempts ?? .try3
    }
    
    func setAppLockAttempts(_ value: AppLockAttempts) {
        userDefaultsDataSource.setAppLockAttempts(value)
    }
    
    var appLockBlockTime: AppLockBlockTime? {
        userDefaultsDataSource.appLockBlockTime
    }
    
    func clearAppLockBlockTime() {
        userDefaultsDataSource.clearAppLockBlockTime()
    }
    
    func setAppLockBlockTime(_ value: AppLockBlockTime) {
        userDefaultsDataSource.setAppLockBlockTime(value)
    }
    
    var lockAppUntil: Date? {
        userDefaultsDataSource.lockAppUntil
    }
    
    func setLockAppUntil(date: Date) {
        userDefaultsDataSource.setLockAppUntil(date: date)
    }
    
    func clearLockAppUntil() {
        userDefaultsDataSource.clearLockAppUntil()
    }
    
    var incorrectLoginCountAttemp: Int {
        userDefaultsDataSource.incorrectLoginCountAttemp
    }
    
    func setIncorrectLoginCountAttempt(_ count: Int) {
        userDefaultsDataSource.setIncorrectLoginCountAttempt(count)
    }
    
    func clearIncorrectLoginCountAttempt() {
        userDefaultsDataSource.clearIncorrectLoginCountAttempt()
    }
    
    var incorrectBiometryCountAttemp: Int {
        userDefaultsDataSource.incorrectBiometryCountAttemp
    }
    
    func setIncorrectBiometryCountAttempt(_ count: Int) {
        userDefaultsDataSource.setIncorrectBiometryCountAttempt(count)
    }
    
    func clearIncorrectBiometryCountAttempt() {
        userDefaultsDataSource.clearIncorrectBiometryCountAttempt()
    }
}
