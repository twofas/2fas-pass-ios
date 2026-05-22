// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Testing
import Foundation
import os
import Common
import Backup

@Suite struct BackupSyncSessionTests {

    // MARK: - Sync ordering

    @Test func syncAllRunsServicesInRegistrationOrder() async {
        let first = FakeSynchronizer(kind: .webDAV)
        let second = FakeSynchronizer(kind: .s3)

        let session = BackupSyncSession(services: [first, second])
        let results = await session.run()

        #expect(results.map(\.id) == [first.id, second.id])
        #expect(results.map(\.kind) == [.webDAV, .s3])
    }

    /// Services are reordered by oldest successful `lastSyncDate` first; entries with no recorded
    /// sync (`nil`) sort before any dated entry so brand-new configs and never-synced backends get
    /// priority on first sync.
    @Test func syncAllRunsServicesByLastSyncDateAscending() async {
        let neverSynced = FakeSynchronizer(kind: .webDAV)
        let oldest = FakeSynchronizer(kind: .s3)
        let newest = FakeSynchronizer(kind: .iCloud)

        let now = Date()
        let dates: [UUID: Date] = [
            oldest.id: now.addingTimeInterval(-7200),
            newest.id: now.addingTimeInterval(-3600)
            // neverSynced.id intentionally absent → nil
        ]

        // Pass them in a non-matching input order to prove the sort actually runs.
        let session = BackupSyncSession(
            services: [newest, oldest, neverSynced],
            lastSyncDate: { dates[$0] }
        )
        let results = await session.run()

        #expect(results.map(\.id) == [neverSynced.id, oldest.id, newest.id])
    }

    /// When two services share the same `lastSyncDate`, the original input array order is the
    /// stable tiebreaker. This is what keeps `syncAllRunsServicesInRegistrationOrder` valid: with
    /// no date provider supplied, every service ties at `nil` and falls back to input order.
    @Test func syncAllPreservesInputOrderWhenDatesTie() async {
        let a = FakeSynchronizer(kind: .webDAV)
        let b = FakeSynchronizer(kind: .s3)

        let sameDate = Date(timeIntervalSince1970: 1_700_000_000)
        let dates: [UUID: Date] = [a.id: sameDate, b.id: sameDate]

        let session = BackupSyncSession(
            services: [a, b],
            lastSyncDate: { dates[$0] }
        )
        let results = await session.run()

        #expect(results.map(\.id) == [a.id, b.id])
    }

    @Test func syncAllForwardsOverwritingFlagToServices() async {
        let fake = FakeSynchronizer(kind: .webDAV)

        let session = BackupSyncSession(services: [fake], overwritingVault: { _ in true })
        _ = await session.run()

        #expect(fake.recording.lastOverwriting == true)
    }

    /// Only the service whose id is `true` in the closure should see
    /// `overwritingVault: true` — the guarantee post-password-change relies on.
    @Test func syncAllResolvesOverwritingPerService() async {
        let marked = FakeSynchronizer(kind: .webDAV)
        let unmarked = FakeSynchronizer(kind: .s3)

        let session = BackupSyncSession(
            services: [marked, unmarked],
            overwritingVault: { id in id == marked.id }
        )
        _ = await session.run()

        #expect(marked.recording.lastOverwriting == true)
        #expect(unmarked.recording.lastOverwriting == false)
    }

    @Test func syncAllContinuesAfterServiceFailure() async throws {
        let failing = FakeSynchronizer(kind: .webDAV, error: .unauthorized)
        let succeeding = FakeSynchronizer(kind: .s3)

        let session = BackupSyncSession(services: [failing, succeeding])
        let results = await session.run()

        try #require(results.count == 2)
        guard case .failure = results[0].outcome else {
            Issue.record("expected first result to be failure")
            return
        }
        guard case .success = results[1].outcome else {
            Issue.record("expected second result to be success")
            return
        }
        #expect(succeeding.recording.calls == 1)
    }

    @Test func syncAllReturnsEmptyForEmptyInput() async {
        let session = BackupSyncSession(services: [])
        let results = await session.run()
        #expect(results.isEmpty)
    }

    @Test func cancellationStopsBetweenServices() async {
        let slow = FakeSynchronizer(kind: .webDAV, workDuration: .seconds(10))
        let next = FakeSynchronizer(kind: .s3)

        let session = BackupSyncSession(services: [slow, next])
        let task = Task { await session.run() }

        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()
        let results = await task.value

        #expect(slow.recording.calls == 1, "first service should have been entered")
        #expect(next.recording.calls == 0, "second service must not run after cancellation")
        #expect(results.count == 1, "only the cancelled first service should appear in results")
    }

    /// Single-service sessions return a one-element results array. The convergence loop runs one
    /// pass, finds no peers to re-queue, and terminates. Container's `sync(_ id:)` relies on this.
    @Test func runWithSingleServiceReturnsOneResult() async throws {
        let fake = FakeSynchronizer(kind: .webDAV)

        let session = BackupSyncSession(services: [fake])
        let results = await session.run()

        try #require(results.count == 1)
        guard case .success = results[0].outcome else {
            Issue.record("expected success, got \(results[0].outcome)")
            return
        }
        #expect(fake.recording.calls == 1)
    }

    @Test func syncAllRunsMultipleServicesOfSameKind() async {
        let webDAV1 = FakeSynchronizer(kind: .webDAV)
        let webDAV2 = FakeSynchronizer(kind: .webDAV)

        let session = BackupSyncSession(services: [webDAV1, webDAV2])
        let results = await session.run()

        #expect(results.map(\.id) == [webDAV1.id, webDAV2.id], "two webDAV instances are tracked separately")
        #expect(webDAV1.recording.calls == 1)
        #expect(webDAV2.recording.calls == 1)
    }

    /// Smoke test that `.iCloud` (the third backend kind) doesn't perturb ordering or
    /// convergence — the session only sees `BackupSynchronizing`.
    @Test func syncAllRoundTripsiCloudKind() async throws {
        let iCloud = FakeSynchronizer(
            kind: .iCloud,
            outcome: BackupSyncOutcome(appliedRemoteChanges: true)
        )
        let webDAV = FakeSynchronizer(kind: .webDAV)

        let session = BackupSyncSession(services: [iCloud, webDAV])
        let results = await session.run()

        #expect(results.map(\.kind) == [.iCloud, .webDAV])
        #expect(iCloud.recording.calls == 1)
        #expect(webDAV.recording.calls == 2, "iCloud's appliedRemoteChanges must re-queue the WebDAV peer")
    }

    // MARK: - Convergence loop

    /// When a later-iterated service applies remote changes, an earlier-iterated peer that already
    /// completed its sync this pass must run again so its remote learns about the new local state.
    @Test func syncAllReRunsEarlierPeerWhenLaterServiceAppliesRemoteChanges() async {
        let earlier = FakeSynchronizer(kind: .webDAV)
        let later = FakeSynchronizer(
            kind: .s3,
            outcomes: [BackupSyncOutcome(appliedRemoteChanges: true)]
        )

        let session = BackupSyncSession(services: [earlier, later])
        _ = await session.run()

        #expect(earlier.recording.calls == 2, "earlier peer must be re-run after later peer pulled changes")
        #expect(later.recording.calls == 1, "the service that pulled does not need to re-run itself")
    }

    /// When the FIRST-iterated service applies remote changes, peers later in the same pass run
    /// once with the updated local state — no second pass needed.
    @Test func syncAllDoesNotRePassWhenChangesAppliedBeforePeers() async {
        let first = FakeSynchronizer(
            kind: .webDAV,
            outcomes: [BackupSyncOutcome(appliedRemoteChanges: true)]
        )
        let second = FakeSynchronizer(kind: .s3)

        let session = BackupSyncSession(services: [first, second])
        _ = await session.run()

        #expect(first.recording.calls == 1)
        #expect(second.recording.calls == 1, "later peer in same pass already runs with new local state")
    }

    /// All services quiescent → exactly one pass.
    @Test func syncAllStopsAfterOnePassWhenAllServicesQuiescent() async {
        let a = FakeSynchronizer(kind: .webDAV)
        let b = FakeSynchronizer(kind: .s3)

        let session = BackupSyncSession(services: [a, b])
        _ = await session.run()

        #expect(a.recording.calls == 1)
        #expect(b.recording.calls == 1)
    }

    /// `appliedRemoteChanges` should be OR'd across passes — a service that applied changes in any
    /// pass must report true in the final aggregated result, even if its last pass was quiescent.
    @Test func syncAllAggregatesAppliedRemoteChangesAcrossPasses() async throws {
        let a = FakeSynchronizer(
            kind: .webDAV,
            // Pass 1: quiescent. Pass 2: applies changes (because B caused a re-pass).
            outcomes: [
                BackupSyncOutcome(appliedRemoteChanges: false),
                BackupSyncOutcome(appliedRemoteChanges: true)
            ]
        )
        let b = FakeSynchronizer(
            kind: .s3,
            // Pass 1: applies changes (this re-queues A). Pass 2: quiescent.
            outcomes: [BackupSyncOutcome(appliedRemoteChanges: true)]
        )

        let session = BackupSyncSession(services: [a, b])
        let results = await session.run()

        #expect(a.recording.calls == 2)
        #expect(b.recording.calls == 2)

        let resultsByID = Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0.outcome) })
        let aOutcome = try #require(resultsByID[a.id])
        let bOutcome = try #require(resultsByID[b.id])
        guard case .success(let aSuccess) = aOutcome,
              case .success(let bSuccess) = bOutcome else {
            Issue.record("expected both services to succeed")
            return
        }
        #expect(aSuccess.appliedRemoteChanges == true, "A's pass-2 success should propagate via OR")
        #expect(bSuccess.appliedRemoteChanges == true, "B's pass-1 success should propagate via OR")
    }

    /// A failing service must not re-queue its peers: failure means we don't know the state
    /// changed, and re-running peers would just pile up duplicate failures.
    @Test func syncAllFailureDoesNotTriggerPeerReRuns() async {
        let failing = FakeSynchronizer(kind: .webDAV, error: .unauthorized)
        let quiet = FakeSynchronizer(kind: .s3)

        let session = BackupSyncSession(services: [failing, quiet])
        _ = await session.run()

        #expect(failing.recording.calls == 1, "failure not retried within run")
        #expect(quiet.recording.calls == 1, "peer not re-run because peer's failure cannot have applied changes")
    }

    /// Pathological oscillation must not loop forever — the session caps at a small number of
    /// passes. With two services both always claiming to apply changes, each pass runs both, so
    /// total invocations equal 2 * maxPasses.
    @Test func syncAllRespectsMaxConvergencePasses() async {
        let a = FakeSynchronizer(
            kind: .webDAV,
            outcome: BackupSyncOutcome(appliedRemoteChanges: true)
        )
        let b = FakeSynchronizer(
            kind: .s3,
            outcome: BackupSyncOutcome(appliedRemoteChanges: true)
        )

        let session = BackupSyncSession(services: [a, b])
        _ = await session.run()

        // The cap is private; assert "bounded" rather than coupling the test to the exact value.
        #expect(a.recording.calls > 1, "convergence should re-run when changes are applied")
        #expect(a.recording.calls <= 10, "convergence must terminate, not loop forever")
        #expect(b.recording.calls == a.recording.calls, "both services run once per pass")
    }
}

// MARK: - Test fake

private final class FakeSynchronizer: BackupSynchronizing, @unchecked Sendable {
    struct Recording {
        var calls: Int = 0
        var currentConcurrent: Int = 0
        var maxConcurrent: Int = 0
        var lastOverwriting: Bool = false
    }

    private struct State {
        var recording = Recording()
        var queuedOutcomes: [BackupSyncOutcome] = []
    }

    let id: UUID
    let kind: BackupSyncService
    private let fallbackOutcome: BackupSyncOutcome
    private let error: BackupSyncError?
    private let workDuration: Duration
    private let state: OSAllocatedUnfairLock<State>

    /// `outcomes` is consumed one-per-call; once exhausted, every further call returns `outcome`.
    /// Use `outcomes` to model "first call applies remote changes, subsequent calls are quiescent"
    /// scenarios that exercise the convergence loop.
    init(
        kind: BackupSyncService,
        outcome: BackupSyncOutcome = BackupSyncOutcome(appliedRemoteChanges: false),
        outcomes: [BackupSyncOutcome] = [],
        error: BackupSyncError? = nil,
        workDuration: Duration = .zero
    ) {
        self.id = UUID()
        self.kind = kind
        self.fallbackOutcome = outcome
        self.error = error
        self.workDuration = workDuration
        self.state = OSAllocatedUnfairLock(initialState: State(queuedOutcomes: outcomes))
    }

    var recording: Recording { state.withLock { $0.recording } }

    func performSync(
        overwritingVault: Bool,
        allowingAnyDeviceId: Bool
    ) async throws(BackupSyncError) -> BackupSyncOutcome {
        let nextOutcome: BackupSyncOutcome = state.withLock { state in
            state.recording.calls += 1
            state.recording.currentConcurrent += 1
            state.recording.maxConcurrent = max(state.recording.maxConcurrent, state.recording.currentConcurrent)
            state.recording.lastOverwriting = overwritingVault
            if !state.queuedOutcomes.isEmpty {
                return state.queuedOutcomes.removeFirst()
            }
            return fallbackOutcome
        }
        defer {
            state.withLock { $0.recording.currentConcurrent -= 1 }
        }

        if workDuration > .zero {
            do {
                try await Task.sleep(for: workDuration)
            } catch {
                throw BackupSyncError.cancelled
            }
        }

        if let error {
            throw error
        }
        return nextOutcome
    }
}
