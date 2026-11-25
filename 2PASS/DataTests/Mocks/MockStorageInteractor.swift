// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
@testable import Data

/// `initialize(completion:)` completes synchronously.
final class MockStorageInteractor: StorageInteracting, CallTrackingMock {

    // MARK: - Call Tracking

    var methodCalls: [String] = []
    let callLog: MockCallLog?

    init(callLog: MockCallLog? = nil) {
        self.callLog = callLog
    }

    // MARK: - Stub Configuration

    private var stubbedCreateNewVault: (VaultID) -> VaultID? = { $0 }
    private var stubbedUpdateExistingVault = true

    @discardableResult
    func withCreateNewVault(_ handler: @escaping (VaultID) -> VaultID?) -> Self {
        stubbedCreateNewVault = handler
        return self
    }

    @discardableResult
    func withUpdateExistingVault(_ value: Bool) -> Self {
        stubbedUpdateExistingVault = value
        return self
    }

    // MARK: - StorageInteracting

    @MainActor
    func loadStore() async {
        recordCall()
    }

    func initialize(completion: @escaping () -> Void) {
        recordCall()
        completion()
    }

    func createNewVault(
        masterKey: Data,
        appKey: Data,
        vaultID: VaultID,
        creationDate: Date?,
        modificationDate: Date?
    ) -> VaultID? {
        recordCall()
        return stubbedCreateNewVault(vaultID)
    }

    func updateExistingVault(with masterKey: Data, appKey: Data) -> Bool {
        recordCall()
        return stubbedUpdateExistingVault
    }

    func clear() {
        recordCall()
    }
}
