// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
@testable import Data

final class MockMigrationInteractor: MigrationInteracting, CallTrackingMock {

    // MARK: - Call Tracking

    var methodCalls: [String] = []
    let callLog: MockCallLog?

    init(callLog: MockCallLog? = nil) {
        self.callLog = callLog
    }

    // MARK: - Stub Configuration

    private var stubbedRequiresReencryptionMigration = false
    private var stubbedLoadStoreWithReencryptionMigration = true

    @discardableResult
    func withRequiresReencryptionMigration(_ value: Bool) -> Self {
        stubbedRequiresReencryptionMigration = value
        return self
    }

    @discardableResult
    func withLoadStoreWithReencryptionMigration(_ value: Bool) -> Self {
        stubbedLoadStoreWithReencryptionMigration = value
        return self
    }

    // MARK: - MigrationInteracting

    func migrateIfNeeded() {
        recordCall()
    }

    func migrateStorageIfNeeded() {
        recordCall()
    }

    func requiresReencryptionMigration() -> Bool {
        recordCall()
        return stubbedRequiresReencryptionMigration
    }

    @MainActor
    func loadStoreWithReencryptionMigration() async -> Bool {
        recordCall()
        return stubbedLoadStoreWithReencryptionMigration
    }
}
