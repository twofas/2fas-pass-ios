// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
@testable import Data

final class MockSecurityInteractor: SecurityInteracting, CallTrackingMock {

    // MARK: - Call Tracking

    var methodCalls: [String] = []
    let callLog: MockCallLog?

    init(callLog: MockCallLog? = nil) {
        self.callLog = callLog
    }

    // MARK: - Stub Configuration

    private var stubbedIsAppLocked = false
    private var stubbedAppLockRemainingSeconds: Int?
    private var stubbedIsUserLoggedIn = false

    @discardableResult
    func withIsAppLocked(_ value: Bool) -> Self {
        stubbedIsAppLocked = value
        return self
    }

    @discardableResult
    func withAppLockRemainingSeconds(_ value: Int?) -> Self {
        stubbedAppLockRemainingSeconds = value
        return self
    }

    @discardableResult
    func withIsUserLoggedIn(_ value: Bool) -> Self {
        stubbedIsUserLoggedIn = value
        return self
    }

    // MARK: - SecurityInteracting

    var didLoginLock: NotificationCenter.Notifications { notifications(named: "MockSecurityInteractor.didLoginLock") }
    var didLoginUnlock: NotificationCenter.Notifications { notifications(named: "MockSecurityInteractor.didLoginUnlock") }
    var didLogoutApp: NotificationCenter.Notifications { notifications(named: "MockSecurityInteractor.didLogoutApp") }

    var isAppLocked: Bool { stubbedIsAppLocked }
    var appLockRemainingSeconds: Int? { stubbedAppLockRemainingSeconds }
    var isUserLoggedIn: Bool { stubbedIsUserLoggedIn }

    func logout() {
        recordCall()
    }

    func markCorrectLogin() {
        recordCall()
    }

    func markWrongPassword() {
        recordCall()
    }

    func applicationWillEnterForeground() {
        recordCall()
    }

    func applicationDidEnterBackground() {
        recordCall()
    }

    func applicationDidBecomeActive() {
        recordCall()
    }

    private func notifications(named name: String) -> NotificationCenter.Notifications {
        NotificationCenter.default.notifications(named: Notification.Name(name))
    }
}
