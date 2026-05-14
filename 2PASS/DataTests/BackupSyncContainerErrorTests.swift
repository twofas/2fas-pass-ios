// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Testing
import Foundation
import os
@testable import Backup

/// Pins the in-memory `lastSyncError(for:)` surface on `BackupSyncContainer`. The container
/// observes session `.finished` events and records on `.failure` (except `.cancelled`) / clears
/// on `.success`; these tests drive deterministic outcomes through the test-only init's
/// `servicesProvider` and assert post-conditions on the public read accessor.
@Suite struct BackupSyncContainerErrorTests {

    @Test func recordsErrorOnFinishedFailure() async throws {
        let failing = ProgrammableSynchronizer(kind: .webDAV, error: .unauthorized)
        let container = BackupSyncContainer(servicesProvider: { [failing] in [failing] })

        _ = try? await container.syncAll()

        let error = try #require(container.lastSyncError(for: failing.id))
        guard case .unauthorized = error else {
            Issue.record("expected .unauthorized, got \(error)")
            return
        }
    }

    @Test func clearsErrorOnSubsequentSuccess() async throws {
        let toggling = ProgrammableSynchronizer(kind: .s3, error: .network(underlying: TestNetworkError()))
        let container = BackupSyncContainer(servicesProvider: { [toggling] in [toggling] })

        _ = try? await container.syncAll()
        try #require(container.lastSyncError(for: toggling.id) != nil)

        // Flip the fake to succeed on the next call, then re-run.
        toggling.setError(nil)
        _ = try? await container.syncAll()

        #expect(container.lastSyncError(for: toggling.id) == nil)
    }

    @Test func cancelledOutcomeDoesNotRecordError() async throws {
        let cancelling = ProgrammableSynchronizer(kind: .webDAV, error: .cancelled)
        let container = BackupSyncContainer(servicesProvider: { [cancelling] in [cancelling] })

        _ = try? await container.syncAll()

        // `.cancelled` is filtered out at recording time — user-initiated cancel is not a "last
        // error" worth surfacing. The container leaves the slot empty (or any prior error in
        // place; here there's no prior so the slot is `nil`).
        #expect(container.lastSyncError(for: cancelling.id) == nil)
    }

    @Test func cancelledDoesNotEvictPriorError() async throws {
        // First a real failure → recorded. Then `.cancelled` → must NOT clear it. This pins the
        // intent of the `case .failure(.cancelled): break` branch in the container's handler.
        let toggling = ProgrammableSynchronizer(kind: .s3, error: .forbidden)
        let container = BackupSyncContainer(servicesProvider: { [toggling] in [toggling] })

        _ = try? await container.syncAll()
        try #require(container.lastSyncError(for: toggling.id) != nil)

        toggling.setError(.cancelled)
        _ = try? await container.syncAll()

        let error = try #require(container.lastSyncError(for: toggling.id))
        guard case .forbidden = error else {
            Issue.record("expected prior .forbidden to remain, got \(error)")
            return
        }
    }

    @Test func errorsAreIsolatedPerConfigID() async throws {
        let failing = ProgrammableSynchronizer(kind: .webDAV, error: .forbidden)
        let succeeding = ProgrammableSynchronizer(kind: .s3)
        let container = BackupSyncContainer(servicesProvider: { [failing, succeeding] in [failing, succeeding] })

        _ = try? await container.syncAll()

        // Failing config records its error; sibling stays clean. Pins that the lock-protected
        // dictionary is keyed correctly and that one service's outcome doesn't leak across.
        let failingError = try #require(container.lastSyncError(for: failing.id))
        guard case .forbidden = failingError else {
            Issue.record("expected .forbidden on failing config, got \(failingError)")
            return
        }
        #expect(container.lastSyncError(for: succeeding.id) == nil)
    }

    @Test func unexpectedErrorPreservesAssociatedDetail() async throws {
        let failing = ProgrammableSynchronizer(kind: .s3, error: .unexpected("status 503"))
        let container = BackupSyncContainer(servicesProvider: { [failing] in [failing] })

        _ = try? await container.syncAll()

        let error = try #require(container.lastSyncError(for: failing.id))
        // Storing the structured `BackupSyncError` directly preserves its associated values —
        // `.unexpected` carries the original `String` payload through to the UI, where
        // `LocalizedError.errorDescription` interpolates it into the localized template.
        guard case .unexpected(let detail) = error else {
            Issue.record("expected .unexpected(...), got \(error)")
            return
        }
        #expect(detail == "status 503")
    }

    @Test func schemaNotSupportedPreservesVersion() async throws {
        let failing = ProgrammableSynchronizer(kind: .webDAV, error: .schemaNotSupported(version: 99))
        let container = BackupSyncContainer(servicesProvider: { [failing] in [failing] })

        _ = try? await container.syncAll()

        let error = try #require(container.lastSyncError(for: failing.id))
        guard case .schemaNotSupported(let version) = error else {
            Issue.record("expected .schemaNotSupported(...), got \(error)")
            return
        }
        #expect(version == 99)
    }
}

// MARK: - Test fakes

/// Minimal `BackupSynchronizing` fake whose outcome can be flipped between calls. The `error`
/// slot is mutable behind a lock so a single instance can be re-used across multiple `syncAll`
/// invocations within one test (failure → success transition).
private final class ProgrammableSynchronizer: BackupSynchronizing, @unchecked Sendable {
    let id = UUID()
    let kind: BackupSyncService

    private let state: OSAllocatedUnfairLock<BackupSyncError?>

    init(kind: BackupSyncService, error: BackupSyncError? = nil) {
        self.kind = kind
        self.state = OSAllocatedUnfairLock(initialState: error)
    }

    func setError(_ error: BackupSyncError?) {
        state.withLock { $0 = error }
    }

    func performSync(
        overwritingVault: Bool,
        allowingAnyDeviceId: Bool
    ) async throws(BackupSyncError) -> BackupSyncOutcome {
        if let error = state.withLock({ $0 }) {
            throw error
        }
        return BackupSyncOutcome(appliedRemoteChanges: false)
    }
}

private struct TestNetworkError: Error, Sendable {}
