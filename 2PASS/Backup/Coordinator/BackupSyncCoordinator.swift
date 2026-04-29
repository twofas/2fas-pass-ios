// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

/// Runs supplied sync services through a single serial queue.
///
/// Stateless apart from its task chain: callers provide the services to run on each call. This
/// keeps the coordinator focused on orchestration — serial execution, convergence, cancellation,
/// failure isolation — and lets callers (e.g. `BackupSyncContainer`) own the question of which
/// services exist.
///
/// **Concurrency contract.** Every `syncAll` / `sync` invocation chains behind any earlier sync
/// work on this coordinator, so two calls fired from different triggers cannot interleave. Within
/// a single `syncAll`, the supplied services run one at a time in array order.
///
/// Actor isolation alone is insufficient because each service call awaits non-actor async work,
/// which releases the actor and would let parallel `syncAll` calls enter. The coordinator builds
/// an explicit task chain on top of actor isolation: each call captures the previous chain tail,
/// installs itself as the new tail, then awaits the predecessor before doing its work. The tail
/// also serves as the cancellation forwarding point.
public actor BackupSyncCoordinator {

    public typealias SyncResult = (id: UUID, kind: SyncServiceKind, outcome: Result<BackupSyncOutcome, BackupSyncError>)

    private var tail: Task<Void, Never>?

    public init() {}

    // MARK: - Sync

    /// Runs every supplied service sequentially, then re-runs services as needed to converge to a
    /// consistent local state across all backends.
    ///
    /// **Convergence loop.** When a service applies remote changes (i.e. pulls something new into
    /// the local database), every other service's remote is now stale relative to the new local
    /// state. The coordinator marks all other services as needing another sync and runs another
    /// pass. The loop terminates when an entire pass completes with no service applying remote
    /// changes — at that point, all remotes are in sync with each other.
    ///
    /// **Failure isolation.** A service's failure does not abort the rest — each service's outcome
    /// is reported in the returned array. A failed service does not re-queue its peers (it cannot
    /// have applied remote changes if it failed).
    ///
    /// **Result semantics.** The returned `[SyncResult]` reports each service's *final* outcome.
    /// `appliedRemoteChanges` is OR'd across passes, so callers can detect whether any work was
    /// done across the whole convergence loop. Services run multiple times appear once.
    ///
    /// **Cancellation.** Cooperative cancellation is checked between services and between passes.
    /// If the caller's task is cancelled mid-iteration, the in-flight service receives the
    /// cancellation; remaining services are not invoked and absent from the result.
    ///
    /// **Pass cap.** A `maxConvergencePasses` ceiling guards against pathological oscillation.
    @discardableResult
    public func syncAll(
        _ services: [any BackupSynchronizing],
        overwritingVault: Bool = false
    ) async -> [SyncResult] {
        await runOnSerialQueue {
            await Self.runUntilQuiescent(services, overwritingVault: overwritingVault)
        }
    }

    /// Runs a single service through the serial queue.
    @discardableResult
    public func sync(
        _ service: any BackupSynchronizing,
        overwritingVault: Bool = false
    ) async -> Result<BackupSyncOutcome, BackupSyncError> {
        await runOnSerialQueue {
            await Self.runService(service, overwritingVault: overwritingVault)
        }
    }

    /// Chains `work` behind any in-flight sync work on this coordinator.
    ///
    /// The implementation captures the current tail and creates a new task that first awaits the
    /// predecessor and then runs the work. The new task becomes the chain's tail so subsequent
    /// callers wait for it. Caller cancellation is forwarded to the work task via
    /// `withTaskCancellationHandler` so cancelling the caller cancels the work — but does not
    /// cancel later-chained callers, which run normally once the predecessor completes.
    private func runOnSerialQueue<T: Sendable>(_ work: @Sendable @escaping () async -> T) async -> T {
        let predecessor = tail
        let workTask = Task<T, Never> {
            await predecessor?.value
            return await work()
        }
        tail = Task<Void, Never> { _ = await workTask.value }

        return await withTaskCancellationHandler {
            await workTask.value
        } onCancel: {
            workTask.cancel()
        }
    }

    private static let maxConvergencePasses = 5

    private static func runUntilQuiescent(
        _ services: [any BackupSynchronizing],
        overwritingVault: Bool
    ) async -> [SyncResult] {
        guard !services.isEmpty else { return [] }
        let allIDs = services.map(\.id)
        let kindByID: [UUID: SyncServiceKind] = Dictionary(
            uniqueKeysWithValues: services.map { ($0.id, $0.kind) }
        )
        var needsSync = Set(allIDs)
        var aggregate: [UUID: Result<BackupSyncOutcome, BackupSyncError>] = [:]
        var pass = 0

        while !needsSync.isEmpty {
            if Task.isCancelled { break }
            if pass >= maxConvergencePasses {
                Log("BackupSyncCoordinator - reached max convergence passes (\(maxConvergencePasses)), stopping", module: .backup)
                break
            }

            for service in services {
                if Task.isCancelled { break }
                guard needsSync.contains(service.id) else { continue }

                let outcome = await runService(service, overwritingVault: overwritingVault && pass == 0)
                needsSync.remove(service.id)
                merge(outcome, for: service.id, into: &aggregate)

                if case .success(let result) = outcome, result.appliedRemoteChanges {
                    // Every other service's remote is now stale relative to the merged local state.
                    for peer in allIDs where peer != service.id {
                        needsSync.insert(peer)
                    }
                }
            }

            pass += 1
        }

        return allIDs.compactMap { id in
            guard let outcome = aggregate[id], let kind = kindByID[id] else { return nil }
            return (id: id, kind: kind, outcome: outcome)
        }
    }

    /// Merges a fresh per-pass outcome into the cross-pass aggregate. The success/failure verdict
    /// reflects the latest attempt; `appliedRemoteChanges` is OR'd so callers see whether any pass
    /// pulled new content for this service.
    private static func merge(
        _ outcome: Result<BackupSyncOutcome, BackupSyncError>,
        for id: UUID,
        into aggregate: inout [UUID: Result<BackupSyncOutcome, BackupSyncError>]
    ) {
        switch (aggregate[id], outcome) {
        case (.success(let prior)?, .success(let curr)):
            aggregate[id] = .success(BackupSyncOutcome(
                appliedRemoteChanges: prior.appliedRemoteChanges || curr.appliedRemoteChanges
            ))
        default:
            aggregate[id] = outcome
        }
    }

    private static func runService(
        _ service: any BackupSynchronizing,
        overwritingVault: Bool
    ) async -> Result<BackupSyncOutcome, BackupSyncError> {
        do {
            let outcome = try await service.performSync(overwritingVault: overwritingVault)
            return .success(outcome)
        } catch {
            Log("BackupSyncCoordinator - service \(service.kind.rawValue) failed", module: .backup)
            return .failure(error)
        }
    }
}
