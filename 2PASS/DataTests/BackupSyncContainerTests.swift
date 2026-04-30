// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Testing
import Foundation
import os
@testable import Backup

@Suite struct BackupSyncContainerTests {

    @Test func syncAllPublishesActivityAndClearsAfterFinish() async throws {
        let service = FakeSynchronizer(kind: .webDAV, workDuration: .milliseconds(150))
        let container = BackupSyncContainer(servicesProvider: { [service] in [service] })

        let notifications = Task { () -> [BackupSyncActivity] in
            var activities: [BackupSyncActivity] = []
            var sawRunning = false
            for await _ in NotificationCenter.default.notifications(named: .backupSyncActivityChanged) {
                let activity = container.currentActivity
                activities.append(activity)
                sawRunning = sawRunning || activity.isRunning
                if sawRunning && activity == .idle {
                    break
                }
            }
            return activities
        }

        let task = try #require(container.syncAllTask())
        let results = await task.value
        let activities = await notifications.value

        #expect(results.count == 1)
        #expect(activities.contains { $0.isRunning && $0.activeConfigIDs == Set([service.id]) })
        #expect(activities.last == .idle)
        #expect(container.currentActivity == .idle)
    }

    @Test func cancelCurrentSyncCancelsActiveRunAndClearsActivity() async throws {
        let slow = FakeSynchronizer(kind: .webDAV, workDuration: .seconds(10))
        let next = FakeSynchronizer(kind: .s3)
        let container = BackupSyncContainer(servicesProvider: { [slow, next] in [slow, next] })

        let runTask = try #require(container.syncAllTask())

        try await waitUntil {
            container.currentActivity.activeConfigIDs.contains(slow.id)
        }

        container.cancelCurrentSync()
        let results = await runTask.value

        #expect(slow.recording.calls == 1)
        #expect(next.recording.calls == 0)
        #expect(container.currentActivity == .idle)
        #expect(results.count == 1)
        guard case .failure(let error) = results[0].outcome else {
            Issue.record("expected the cancelled service to report failure")
            return
        }
        guard case .cancelled = error else {
            Issue.record("expected cancellation error, got \(error)")
            return
        }
    }
}

private func waitUntil(
    timeout: Duration = .seconds(2),
    interval: Duration = .milliseconds(20),
    condition: @escaping @Sendable () -> Bool
) async throws {
    let clock = ContinuousClock()
    let start = clock.now
    while !condition() {
        if clock.now - start > timeout {
            throw WaitUntilTimedOut()
        }
        try await Task.sleep(for: interval)
    }
}

private struct WaitUntilTimedOut: Error {}

private final class FakeSynchronizer: BackupSynchronizing, @unchecked Sendable {
    struct Recording {
        var calls = 0
    }

    let id = UUID()
    let kind: SyncServiceKind

    private let workDuration: Duration
    private let state = OSAllocatedUnfairLock(initialState: Recording())

    init(kind: SyncServiceKind, workDuration: Duration = .zero) {
        self.kind = kind
        self.workDuration = workDuration
    }

    var recording: Recording {
        state.withLock { $0 }
    }

    func performSync(overwritingVault: Bool) async throws(BackupSyncError) -> BackupSyncOutcome {
        state.withLock { $0.calls += 1 }
        if workDuration > .zero {
            do {
                try await Task.sleep(for: workDuration)
            } catch {
                throw BackupSyncError.cancelled
            }
        }
        return BackupSyncOutcome(appliedRemoteChanges: false)
    }
}
