// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup

/// CRUD-style access to the backup-sync configs.
///
/// Wraps `MainRepository`'s persistence methods directly — does not reach through the
/// `BackupSyncContainer`. UI flows that need a single homogeneous list of all configured
/// backends (settings screens, "all backends" overview) consume this interactor; flows that
/// need per-kind specifics filter `allConfigs` themselves via the
/// `[BackupConfig].webDAVEntries` / `.s3Entries` extensions.
public protocol BackupSyncConfigsInteracting: AnyObject {
    /// Every registered config in registration order.
    var allConfigs: [BackupConfig] { get }

    /// Most recent successful sync timestamp for `id`, or `nil` if no successful sync recorded.
    /// Reads through to the persistent date store; intended for UI display ("Last synced …").
    func lastSyncDate(for id: UUID) -> Date?

    /// Adds a new WebDAV backend; returns the assigned id.
    @discardableResult
    func addWebDAVConfig(_ config: BackupWebDAVConfig) -> UUID

    /// Adds a new S3 backend; returns the assigned id.
    @discardableResult
    func addS3Config(_ config: S3ServiceConfig) -> UUID

    /// Adds the iCloud backend; returns the assigned id, or `nil` if an iCloud entry already
    /// exists. Single-instance: there is exactly one CloudKit container per build, so a
    /// second iCloud config would point at the same data and create a phantom duplicate in
    /// the convergence loop.
    @discardableResult
    func addiCloudConfig() -> UUID?

    /// Replaces the WebDAV config bound to `id`, preserving id and `createdAt`. No-op if the
    /// id either doesn't exist or maps to an entry of another kind.
    func updateWebDAVConfig(id: UUID, with config: BackupWebDAVConfig)

    /// Replaces the S3 config bound to `id`, preserving id and `createdAt`. No-op if the id
    /// either doesn't exist or maps to an entry of another kind.
    func updateS3Config(id: UUID, with config: S3ServiceConfig)

    /// Removes the entry with `id` regardless of kind. No-op if no entry matches.
    func removeConfig(id: UUID)
}

final class BackupSyncConfigsInteractor: BackupSyncConfigsInteracting {
    private let mainRepository: MainRepository

    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }

    var allConfigs: [BackupConfig] {
        mainRepository.loadBackupConfigs()
    }

    func lastSyncDate(for id: UUID) -> Date? {
        mainRepository.loadLastSyncDates()[id]
    }

    @discardableResult
    func addWebDAVConfig(_ config: BackupWebDAVConfig) -> UUID {
        let id = UUID()
        var configs = mainRepository.loadBackupConfigs()
        configs.append(.webDAV(BackupConfigEntry(id: id, createdAt: Date(), config: config)))
        mainRepository.saveBackupConfigs(configs)
        return id
    }

    @discardableResult
    func addS3Config(_ config: S3ServiceConfig) -> UUID {
        let id = UUID()
        var configs = mainRepository.loadBackupConfigs()
        configs.append(.s3(BackupConfigEntry(id: id, createdAt: Date(), config: config)))
        mainRepository.saveBackupConfigs(configs)
        return id
    }

    @discardableResult
    func addiCloudConfig() -> UUID? {
        var configs = mainRepository.loadBackupConfigs()
        guard configs.iCloudEntry == nil else { return nil }
        let id = UUID()
        configs.append(.iCloud(BackupConfigEntry(id: id, createdAt: Date(), config: BackupiCloudConfig())))
        mainRepository.saveBackupConfigs(configs)
        return id
    }

    func updateWebDAVConfig(id: UUID, with config: BackupWebDAVConfig) {
        var configs = mainRepository.loadBackupConfigs()
        guard let idx = configs.firstIndex(where: { $0.id == id }),
              case .webDAV(let existing) = configs[idx] else { return }
        configs[idx] = .webDAV(BackupConfigEntry(id: id, createdAt: existing.createdAt, config: config))
        mainRepository.saveBackupConfigs(configs)
    }

    func updateS3Config(id: UUID, with config: S3ServiceConfig) {
        var configs = mainRepository.loadBackupConfigs()
        guard let idx = configs.firstIndex(where: { $0.id == id }),
              case .s3(let existing) = configs[idx] else { return }
        configs[idx] = .s3(BackupConfigEntry(id: id, createdAt: existing.createdAt, config: config))
        mainRepository.saveBackupConfigs(configs)
    }

    func removeConfig(id: UUID) {
        var configs = mainRepository.loadBackupConfigs()
        guard configs.contains(where: { $0.id == id }) else { return }
        configs.removeAll { $0.id == id }
        mainRepository.saveBackupConfigs(configs)
    }
}
