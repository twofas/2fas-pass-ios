// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

/// Owns a single end-to-end sync run across one or more backup backends. One instance, one
/// `run()` call: callers (in practice `BackupSyncContainer`) build a session with the services
/// they want included, invoke `run()`, and discard the result. Sessions are not designed to be
/// reused — they're cheap allocations whose lifetime makes "where did this sync start?" a
/// trivial question.
///
/// **Not to be confused with `BackupFileSyncSession`.** That type is a per-service adapter
/// (one WebDAV/S3 backend per instance) that conforms to `BackupSynchronizing`. This type is
/// the orchestrator that drives a *set* of those services through the convergence loop.
///
/// **Convergence loop.** Within a single `run()`, the supplied services run sequentially,
/// ordered by oldest successful `lastSyncDate` first (services that have never synced run
/// first); input array order is the stable tiebreaker. The order is computed once and reused
/// across passes. When a service applies remote changes (i.e. pulls something new into the
/// local database), every other service's remote is now stale relative to the new local
/// state — the session marks all peers as needing another sync and runs another pass. The
/// loop terminates when an entire pass completes with no service applying remote changes;
/// at that point, all remotes are in sync with each other.
///
/// **Failure isolation.** A service's failure does not abort the rest — each service's
/// outcome is reported in the returned array. A failed service does not re-queue its peers
/// (it cannot have applied remote changes if it failed).
///
/// **Result semantics.** The returned `[SyncResult]` reports each service's *final* outcome.
/// `appliedRemoteChanges` is OR'd across passes, so callers can detect whether any work was
/// done across the whole convergence loop. Services run multiple times appear once.
///
/// **Cancellation.** Cooperative cancellation is checked between services and between
/// passes. If the caller's task is cancelled mid-iteration, the in-flight service receives
/// the cancellation; remaining services are not invoked and are absent from the result.
///
/// **Pass cap.** A `maxConvergencePasses` ceiling guards against pathological oscillation.
///
/// **Concurrency.** No actor isolation: all stored state is `let`, so the type is naturally
/// `Sendable`. Cross-trigger debouncing — preventing two simultaneous sync runs from racing
/// — is the *container's* concern (`BackupSyncContainer.acquireSyncSlot`), not this type's.
public final class BackupSyncSession: Sendable {

    public typealias SyncResult = (id: BackupConfig.ID, kind: BackupSyncService, outcome: Result<BackupSyncOutcome, BackupSyncError>)

    /// Lifecycle events emitted during a sync. Two granularities, both delivered through the
    /// same `BackupSyncContainer.syncEvents()` stream so a single subscriber can drive both
    /// global "is anything happening?" UI and per-row spinner state.
    ///
    /// **Session-level** (`sessionStarted` / `sessionFinished`) are emitted by the *container*
    /// when its in-progress slot transitions. They cover the whole orchestration window —
    /// services-list construction, convergence passes, post-results notification, and the
    /// inter-service gaps where `activeConfigIDs` is briefly empty but the call hasn't
    /// returned. Use these to drive the call-level "isSyncing" flag.
    ///
    /// **Service-level** (`started` / `finished`) are emitted by the session before/after each
    /// `performSync` invocation. A single service may emit multiple `started`/`finished` pairs
    /// across the convergence loop's passes — that's by design (it really is running again).
    /// Use these to drive per-service UI by inserting on `started` and removing on `finished`.
    /// `finished` carries the per-call outcome.
    public enum Event: Sendable {
        case sessionStarted
        case sessionFinished
        case started(id: BackupConfig.ID, kind: BackupSyncService)
        case finished(id: BackupConfig.ID, kind: BackupSyncService, outcome: Result<BackupSyncOutcome, BackupSyncError>)
    }

    public typealias EventHandler = @Sendable (Event) -> Void

    private let services: [any BackupSynchronizing]
    /// Per-service overwriting decision. Resolved at runtime per `runService` call so the
    /// caller (`BackupSyncContainer`) can supply a function that consults a per-config flag
    /// (e.g. `MainRepository.vaultOverrideAwaitingConfigIDs`). A static "true for everyone"
    /// run is just `{ _ in true }`; the default value `{ _ in false }` keeps existing call
    /// sites and tests that don't care about overwriting compiling unchanged.
    private let overwritingVault: @Sendable (BackupConfig.ID) -> Bool
    /// Per-service multi-device-id override. Same per-id closure shape as `overwritingVault`
    /// so the caller can consult `MainRepository.deviceRegistrationAwaitingConfigIDs` (set
    /// after recovery, cleared on first successful sync) and selectively bypass the gate
    /// only for configs awaiting their first post-recovery sync. Routine syncs default to
    /// `{ _ in false }`.
    private let allowingAnyDeviceId: @Sendable (BackupConfig.ID) -> Bool
    private let lastSyncDate: @Sendable (BackupConfig.ID) -> Date?
    private let onEvent: EventHandler?

    public init(
        services: [any BackupSynchronizing],
        overwritingVault: @Sendable @escaping (BackupConfig.ID) -> Bool = { _ in false },
        allowingAnyDeviceId: @Sendable @escaping (BackupConfig.ID) -> Bool = { _ in false },
        lastSyncDate: @Sendable @escaping (BackupConfig.ID) -> Date? = { _ in nil },
        onEvent: EventHandler? = nil
    ) {
        self.services = services
        self.overwritingVault = overwritingVault
        self.allowingAnyDeviceId = allowingAnyDeviceId
        self.lastSyncDate = lastSyncDate
        self.onEvent = onEvent
    }

    // MARK: - Run

    /// Executes the convergence loop over this session's services and returns each service's
    /// final outcome. Single-service sessions terminate after one pass (no peers to re-queue).
    @discardableResult
    public func run() async -> [SyncResult] {
        guard !services.isEmpty else { return [] }
        let ordered = services.enumerated().sorted { lhs, rhs in
            let l = lastSyncDate(lhs.element.id) ?? .distantPast
            let r = lastSyncDate(rhs.element.id) ?? .distantPast
            if l != r { return l < r }
            return lhs.offset < rhs.offset
        }.map(\.element)
        let allIDs = ordered.map(\.id)
        var needsSync = Set(allIDs)
        var aggregate: [BackupConfig.ID: Result<BackupSyncOutcome, BackupSyncError>] = [:]
        var pass = 0

        while !needsSync.isEmpty {
            if Task.isCancelled { break }
            if pass >= Self.maxConvergencePasses {
                Log("BackupSyncSession - reached max convergence passes (\(Self.maxConvergencePasses)), stopping", module: .backup)
                break
            }

            for service in ordered {
                if Task.isCancelled { break }
                guard needsSync.contains(service.id) else { continue }

                let outcome = await runService(
                    service,
                    overwritingVault: overwritingVault(service.id) && pass == 0,
                    allowingAnyDeviceId: allowingAnyDeviceId(service.id)
                )
                needsSync.remove(service.id)
                Self.merge(outcome, for: service.id, into: &aggregate)

                if case .success(let result) = outcome, result.appliedRemoteChanges {
                    // Every other service's remote is now stale relative to the merged local state.
                    for peer in allIDs where peer != service.id {
                        needsSync.insert(peer)
                    }
                }
            }

            pass += 1
        }

        return ordered.compactMap { service in
            guard let outcome = aggregate[service.id] else { return nil }
            return (id: service.id, kind: service.kind, outcome: outcome)
        }
    }

    private static let maxConvergencePasses = 3

    /// Merges a fresh per-pass outcome into the cross-pass aggregate. The success/failure verdict
    /// reflects the latest attempt; `appliedRemoteChanges` is OR'd so callers see whether any pass
    /// pulled new content for this service.
    private static func merge(
        _ outcome: Result<BackupSyncOutcome, BackupSyncError>,
        for id: BackupConfig.ID,
        into aggregate: inout [BackupConfig.ID: Result<BackupSyncOutcome, BackupSyncError>]
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

    private func runService(
        _ service: any BackupSynchronizing,
        overwritingVault: Bool,
        allowingAnyDeviceId: Bool
    ) async -> Result<BackupSyncOutcome, BackupSyncError> {
        onEvent?(.started(id: service.id, kind: service.kind))
        let result: Result<BackupSyncOutcome, BackupSyncError>
        do {
            let outcome = try await service.performSync(
                overwritingVault: overwritingVault,
                allowingAnyDeviceId: allowingAnyDeviceId
            )
            result = .success(outcome)
        } catch {
            Log("BackupSyncSession - service \(service.kind.rawValue) failed", module: .backup)
            result = .failure(error)
        }
        onEvent?(.finished(id: service.id, kind: service.kind, outcome: result))
        return result
    }
}
