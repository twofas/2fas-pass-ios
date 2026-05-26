// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

/// Single-use; one instance per `run()`. Services run sequentially, ordered by oldest
/// successful `lastSyncDate`. When a service applies remote changes, every peer is
/// re-queued (its remote is now stale); loop stops on a quiet pass or
/// `maxConvergencePasses`. Cancellation cancels the in-flight service and drops the rest
/// from the result.
public final class BackupSyncSession: Sendable {

    public typealias SyncResult = (id: BackupConfig.ID, kind: BackupSyncService, outcome: Result<BackupSyncOutcome, BackupSyncError>)

    /// `sessionStarted`/`sessionFinished` bracket the whole orchestration (emitted by the
    /// container). `started`/`finished` bracket each `performSync` and can repeat across
    /// convergence passes for the same id.
    public enum Event: Sendable {
        case sessionStarted
        case sessionFinished
        case started(id: BackupConfig.ID, kind: BackupSyncService)
        case finished(id: BackupConfig.ID, kind: BackupSyncService, outcome: Result<BackupSyncOutcome, BackupSyncError>)
    }

    public typealias EventHandler = @Sendable (Event) -> Void

    private let services: [any BackupSynchronizing]
    private let overwritingVault: @Sendable (BackupConfig.ID) -> Bool
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
                    // Every other service's remote is now stale relative to merged local state.
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

    /// Verdict reflects the latest attempt; `appliedRemoteChanges` OR'd across passes.
    /// Without this, an earlier pass that pulled changes would be hidden by a later quiet pass.
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
