// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import CoreLocation

public protocol SecurityInteracting: AnyObject {
    var didLoginLock: NotificationCenter.Notifications { get }
    var didLoginUnlock: NotificationCenter.Notifications { get }
    var didLogoutApp: NotificationCenter.Notifications { get }

    var isAppLocked: Bool { get }
    var appLockRemainingSeconds: Int? { get }

    var isUserLoggedIn: Bool { get }
    func logout()
    
    func markCorrectLogin()
    func markWrongPassword()
    
    func applicationWillEnterForeground()
    func applicationDidEnterBackground()
    func applicationDidBecomeActive()
}

final class SecurityInteractor {
    private static let loginLockedNotification = Notification.Name("LoginLocked")
    private static let loginUnlockedNotification = Notification.Name("LoginUnlocked")
    private static let logoutAppNotification = Notification.Name("LogoutApp")

    private let minute = 60
    private var timer: Timer?

    private let mainRepository: MainRepository
    private let storageInteractor: StorageInteracting
    private let protectionInteractor: ProtectionInteracting
    
    init(
        mainRepository: MainRepository,
        storageInteractor: StorageInteracting,
        protectionInteractor: ProtectionInteracting
    ) {
        self.mainRepository = mainRepository
        self.storageInteractor = storageInteractor
        self.protectionInteractor = protectionInteractor
    }
    
    deinit {
        clearTimer()
    }
}

extension SecurityInteractor: SecurityInteracting {
    // MARK: - Login Notifications

    var didLoginLock: NotificationCenter.Notifications {
        NotificationCenter.default.notifications(named: Self.loginLockedNotification)
    }

    var didLoginUnlock: NotificationCenter.Notifications {
        NotificationCenter.default.notifications(named: Self.loginUnlockedNotification)
    }

    var didLogoutApp: NotificationCenter.Notifications {
        NotificationCenter.default.notifications(named: Self.logoutAppNotification)
    }

    // MARK: - Login

    var isUserLoggedIn: Bool {
        mainRepository.isUserLoggedIn
    }
    
    var lockAppUntil: Date? {
        mainRepository.lockAppUntil
    }
    
    var isAppLocked: Bool {
        guard let lockTimestamp = mainRepository.lockAppUntil else { return false }
        
        let isBlocked = currentTimestamp < lockTimestamp
        if !isBlocked {
            mainRepository.clearLockAppUntil()
        }
        return isBlocked
    }
    
    var appLockRemainingSeconds: Int? {
        guard let lockTimestamp = mainRepository.lockAppUntil, currentTimestamp < lockTimestamp else { return nil }
        return Int(lockTimestamp.timeIntervalSince1970 - currentTimestamp.timeIntervalSince1970)
    }
    
    // MARK: - App State
    
    func logout() {
        Log("SecurityInteractor: Logout", module: .interactor)

        if mainRepository.isOnboardingCompleted {
            mainRepository.reloadAuthContext()
            mainRepository.clearAllEmphemeral()
            storageInteractor.clear()
            NotificationCenter.default.post(name: Self.logoutAppNotification, object: nil)
        }
    }
    
    func applicationWillEnterForeground() {
        mainRepository.setIsAppInBackground(false)

        if isAppLocked == true {
            NotificationCenter.default.post(name: Self.loginLockedNotification, object: nil)
        } else {
            NotificationCenter.default.post(name: Self.loginUnlockedNotification, object: nil)
        }
    }

    func applicationDidEnterBackground() {
        mainRepository.setIsAppInBackground(true)
        
        logout()
        clearTimer()
    }

    func applicationDidBecomeActive() {
        if isAppLocked {
            startTimer()
        }
    }
    
    func markCorrectLogin() {
        Log("SecurityInteractor: Mark correct login", module: .interactor)
        clearWrongLogins()
    }
    
    func markWrongPassword() {
        Log("SecurityInteractor: Mark incorrect login", module: .interactor)
        let current = mainRepository.incorrectLoginCountAttemp
        let next = current + 1
        mainRepository.setIncorrectLoginCountAttempt(next)
        if next >= mainRepository.appLockAttempts.value {
            lockApplication()
        }
        if isAppLocked {
            startTimer()
            NotificationCenter.default.post(name: Self.loginLockedNotification, object: nil)
            logout()
        }
    }
}

private extension SecurityInteractor {
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }

            if self.isAppLocked == false {
                self.clearTimer()
                self.unlockApplication()
            }
        })
    }
    
    func clearTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func lockApplication() {
        Log("SecurityInteractor: Lock app", module: .interactor)
        logout()
        
        let appBlockTime = nextAppLockBlockTime
        mainRepository.setAppLockBlockTime(appBlockTime)
        let lockForSeconds = TimeInterval(appBlockTime.value * minute)
        mainRepository.setLockAppUntil(date: Date(timeInterval: lockForSeconds, since: currentTimestamp))
    }
    
    func unlockApplication() {
        Log("SecurityInteractor: Unlock app", module: .interactor)
        protectionInteractor.selectVault()
        NotificationCenter.default.post(name: Self.loginUnlockedNotification, object: nil)
    }
    
    func markWrongBiometry() {
        Log("SecurityInteractor: Mark incorrect biometry login", module: .interactor)
        let current = mainRepository.incorrectBiometryCountAttemp
        let next = current + 1
        mainRepository.setIncorrectBiometryCountAttempt(next)
    }
    
    var currentTimestamp: Date {
        let location = CLLocation(latitude: 0, longitude: 0)
        let timestamp = location.timestamp
        return timestamp
    }
    
    var nextAppLockBlockTime: AppLockBlockTime {
        switch mainRepository.appLockBlockTime {
        case nil: return .min1
        case .min1: return .min3
        case .min3: return .min5
        case .min5: return .min15
        case .min15: return .min60
        case .min60: return .min60
        }
    }
    
    func clearWrongLogins() {
        Log("SecurityInteractor: Clear incorrect logins", module: .interactor)
        mainRepository.clearIncorrectLoginCountAttempt()
        mainRepository.clearIncorrectBiometryCountAttempt()
        mainRepository.clearAppLockBlockTime()
    }
}
