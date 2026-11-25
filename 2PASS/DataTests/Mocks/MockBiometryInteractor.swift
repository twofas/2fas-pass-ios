// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
@testable import Data

final class MockBiometryInteractor: BiometryInteracting, CallTrackingMock {

    // MARK: - Call Tracking

    var methodCalls: [String] = []
    let callLog: MockCallLog?

    init(callLog: MockCallLog? = nil) {
        self.callLog = callLog
    }

    // MARK: - Stub Configuration

    private var stubbedLoginResult: BiometryInteractorLoginResult = .success(MasterKey(repeating: 1, count: 32))
    private var stubbedIsBiometryEnabled = true
    private var stubbedBiometryType: BiometryType = .faceID

    @discardableResult
    func withLoginResult(_ result: BiometryInteractorLoginResult) -> Self {
        stubbedLoginResult = result
        return self
    }

    @discardableResult
    func withIsBiometryEnabled(_ value: Bool) -> Self {
        stubbedIsBiometryEnabled = value
        return self
    }

    @discardableResult
    func withBiometryType(_ value: BiometryType) -> Self {
        stubbedBiometryType = value
        return self
    }

    // MARK: - BiometryInteracting

    var isBiometryLocked: Bool { false }
    var canUseBiometryForLogin: Bool { stubbedIsBiometryEnabled }
    var canEnableBiometry: Bool { true }
    var isBiometryEnabled: Bool { stubbedIsBiometryEnabled }
    var isBiometryAvailable: Bool { true }
    var isBiometryLockedOut: Bool { false }
    var isBiometryDeniedForApp: Bool { false }
    var biometryType: BiometryType { stubbedBiometryType }

    func setBiometryEnabled(_ enabled: Bool, completion: @escaping (Bool) -> Void) {
        recordCall()
        stubbedIsBiometryEnabled = enabled
        completion(enabled)
    }

    @MainActor @discardableResult
    func setUpBiometryForNewMasterKey() async -> Bool {
        recordCall()
        return true
    }

    func loginUsingBiometry(reason: String, result: @escaping (BiometryInteractorLoginResult) -> Void) {
        recordCall()
        result(stubbedLoginResult)
    }
}
