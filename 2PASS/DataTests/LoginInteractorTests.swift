// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Testing
import Foundation
import Common
@testable import Data

@Suite("LoginInteractor Tests")
struct LoginInteractorTests {

    private let callLog = MockCallLog()
    private let migrationInteractor = MockMigrationInteractor()
    private let interactor: LoginInteractor

    init() {
        interactor = LoginInteractor(
            mainRepository: MockMainRepository(),
            protectionInteractor: MockProtectionInteractor(callLog: callLog),
            securityInteractor: MockSecurityInteractor(),
            storageInteractor: MockStorageInteractor(callLog: callLog),
            biometryInteractor: MockBiometryInteractor(),
            migrationInteractor: migrationInteractor
        )
    }

    @Test(arguments: [false, true])
    func passwordLoginSelectsVaultBeforeKeysUnlessReencryptionMigrationIsPending(isMigrationPending: Bool) {
        // GIVEN
        migrationInteractor.withRequiresReencryptionMigration(isMigrationPending)
        var result: LoginMasterPasswordResult?

        // WHEN
        interactor.loginUsingMasterPassword("password") { result = $0 }

        // THEN
        #expect(result == .success)
        #expect(loginSteps == Self.expectedLoginSteps(isMigrationPending: isMigrationPending))
    }

    @Test(arguments: [false, true])
    func biometryLoginSelectsVaultBeforeKeysUnlessReencryptionMigrationIsPending(isMigrationPending: Bool) {
        // GIVEN
        migrationInteractor.withRequiresReencryptionMigration(isMigrationPending)
        var result: LoginBiometryResult?

        // WHEN
        interactor.loginUsingBiometry(reason: "reason") { result = $0 }

        // THEN
        #expect(result == .success)
        #expect(loginSteps == Self.expectedLoginSteps(isMigrationPending: isMigrationPending))
    }

    // MARK: - Helpers

    private static let selectVault = "MockProtectionInteractor.selectVault()"
    private static let setupKeys = "MockProtectionInteractor.setupKeys()"
    private static let initializeStorage = "MockStorageInteractor.initialize(completion:)"

    /// The logged calls narrowed to the three steps whose order the login must keep.
    private var loginSteps: [String] {
        callLog.calls.filter { call in
            [Self.selectVault, Self.setupKeys, Self.initializeStorage].contains(call)
        }
    }

    private static func expectedLoginSteps(isMigrationPending: Bool) -> [String] {
        (isMigrationPending ? [] : [selectVault]) + [setupKeys, initializeStorage]
    }
}
