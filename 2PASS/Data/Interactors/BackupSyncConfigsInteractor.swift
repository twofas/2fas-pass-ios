// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup
import Common

public struct S3EndpointDetection: Equatable {
    public let region: String?
    public let bucket: String?

    public init(region: String?, bucket: String?) {
        self.region = region
        self.bucket = bucket
    }
}

/// CRUD-style access to the backup-sync configs, plus a connection probe used to validate a
/// config before persisting it. Persistence reads/writes go straight to `MainRepository` —
/// orchestrated sync lives in `BackupSyncTriggerInteracting`. The probe is included here
/// because it's a "thing you can do with a config" alongside read/write; it routes through
/// `BackupSyncContainer.testConnection(config:)`, which constructs a transient
/// `BackupFileServiceSession` for the supplied config. Per-kind filtering is left to callers
/// via the `[BackupConfig].webDAVEntries` / `.iCloudEntry` extensions.
public protocol BackupSyncConfigsInteracting: AnyObject {
    /// Every registered config in registration order.
    var allConfigs: [BackupConfig] { get }

    /// Adds a new WebDAV backend; returns the assigned id.
    @discardableResult
    func addWebDAVConfig(_ config: BackupWebDAVConfig) -> BackupConfig.ID

    /// Adds a new S3 backend; returns the assigned id.
    @discardableResult
    func addS3Config(_ config: S3ServiceConfig) -> BackupConfig.ID

    /// Adds the iCloud backend; returns the assigned id, or `nil` if an iCloud entry already
    /// exists. Single-instance: there is exactly one CloudKit container per build, so a
    /// second iCloud config would point at the same data and create a phantom duplicate in
    /// the convergence loop.
    @discardableResult
    func addiCloudConfig() -> BackupConfig.ID?

    /// Replaces the WebDAV config bound to `id`, preserving id and `createdAt`. No-op if the
    /// id either doesn't exist or maps to an entry of another kind.
    func updateWebDAVConfig(id: BackupConfig.ID, with config: BackupWebDAVConfig)

    /// Replaces the S3 config bound to `id`, preserving id and `createdAt`. No-op if the id
    /// either doesn't exist or maps to an entry of another kind.
    func updateS3Config(id: BackupConfig.ID, with config: S3ServiceConfig)

    /// Removes the entry with `id` regardless of kind. No-op if no entry matches.
    func removeConfig(id: BackupConfig.ID)

    /// Typed sequence that emits one element every time configs are persisted via this
    /// interactor (add / update / remove). Mirrors `BackupSyncContainer.configsDidChange` —
    /// surfaced at the interactor seam so consumers don't reach into `NotificationCenter`.
    /// Zero-cost passthrough; each access yields a fresh subscription.
    var configsDidChange: Notifications.MessageSequence<BackupConfigsDidChange> { get }

    /// Read probe: routes through `BackupSyncContainer.testConnection(config:)`, which builds
    /// a transient `BackupFileServiceSession` for the supplied config and runs auth +
    /// index-read in one call. Throws on auth failure, network error, or read denial. Returns
    /// silently on success including the no-index-yet fresh-setup case (`fetchIndex()` 404 is
    /// folded into success).
    func test(_ config: BackupWebDAVConfig) async throws(BackupFileServiceError)
    func test(_ config: S3ServiceConfig) async throws(BackupFileServiceError)

    /// Best-effort parse of standard AWS S3 endpoint shapes. Returns `nil` for non-AWS hosts
    /// since S3-compatible providers (MinIO, Backblaze, R2) use ad-hoc URL shapes that aren't
    /// reliable to auto-parse. Input is normalized first (whitespace trim, scheme add, host
    /// lowercase) so the detection accepts permissive user typing.
    func detectS3Endpoint(_ endpoint: String) -> S3EndpointDetection?
}

final class BackupSyncConfigsInteractor: BackupSyncConfigsInteracting {
    private let mainRepository: MainRepository
    private let currentDateInteractor: CurrentDateInteracting
    private let uriInteractor: URIInteracting

    init(
        mainRepository: MainRepository,
        currentDateInteractor: CurrentDateInteracting,
        uriInteractor: URIInteracting
    ) {
        self.mainRepository = mainRepository
        self.currentDateInteractor = currentDateInteractor
        self.uriInteractor = uriInteractor
    }

    var allConfigs: [BackupConfig] {
        mainRepository.loadBackupConfigs()
    }

    @discardableResult
    func addWebDAVConfig(_ config: BackupWebDAVConfig) -> BackupConfig.ID {
        let id = BackupConfig.ID()
        var configs = mainRepository.loadBackupConfigs()
        configs.append(.webDAV(BackupConfigEntry(id: id, createdAt: currentDateInteractor.currentDate, config: config)))
        mainRepository.backupSyncContainer.saveConfigs(configs)
        return id
    }

    @discardableResult
    func addS3Config(_ config: S3ServiceConfig) -> BackupConfig.ID {
        let id = BackupConfig.ID()
        var configs = mainRepository.loadBackupConfigs()
        configs.append(.s3(BackupConfigEntry(id: id, createdAt: currentDateInteractor.currentDate, config: config)))
        mainRepository.backupSyncContainer.saveConfigs(configs)
        return id
    }

    @discardableResult
    func addiCloudConfig() -> BackupConfig.ID? {
        var configs = mainRepository.loadBackupConfigs()
        guard !configs.hasICloud else { return nil }
        let id = BackupConfig.ID()
        configs.append(.iCloud(BackupConfigEntry(id: id, createdAt: currentDateInteractor.currentDate, config: BackupiCloudConfig())))
        mainRepository.backupSyncContainer.saveConfigs(configs)
        return id
    }

    func updateWebDAVConfig(id: BackupConfig.ID, with config: BackupWebDAVConfig) {
        var configs = mainRepository.loadBackupConfigs()
        guard let idx = configs.firstIndex(where: { $0.id == id }),
              case .webDAV(let existing) = configs[idx] else { return }
        configs[idx] = .webDAV(BackupConfigEntry(id: id, createdAt: existing.createdAt, config: config))
        mainRepository.backupSyncContainer.saveConfigs(configs)
    }

    func updateS3Config(id: BackupConfig.ID, with config: S3ServiceConfig) {
        var configs = mainRepository.loadBackupConfigs()
        guard let idx = configs.firstIndex(where: { $0.id == id }),
              case .s3(let existing) = configs[idx] else { return }
        configs[idx] = .s3(BackupConfigEntry(id: id, createdAt: existing.createdAt, config: config))
        mainRepository.backupSyncContainer.saveConfigs(configs)
    }

    func removeConfig(id: BackupConfig.ID) {
        var configs = mainRepository.loadBackupConfigs()
        guard configs.contains(where: { $0.id == id }) else { return }
        configs.removeAll { $0.id == id }
        mainRepository.backupSyncContainer.saveConfigs(configs)
    }

    var configsDidChange: Notifications.MessageSequence<BackupConfigsDidChange> {
        mainRepository.backupSyncContainer.configsDidChange
    }

    func test(_ config: BackupWebDAVConfig) async throws(BackupFileServiceError) {
        try await mainRepository.backupSyncContainer.testConnection(config: config)
    }

    func test(_ config: S3ServiceConfig) async throws(BackupFileServiceError) {
        try await mainRepository.backupSyncContainer.testConnection(config: config)
    }

    func detectS3Endpoint(_ endpoint: String) -> S3EndpointDetection? {
        guard let url = uriInteractor.normalizeURL(endpoint),
              let host = url.host()
        else { return nil }

        let labels = host.split(separator: ".")
        guard labels.count >= 2,
              labels.suffix(2).joined(separator: ".") == "amazonaws.com"
        else { return nil }

        let core = Array(labels.dropLast(2))
        var region: String?
        var bucket: String?

        switch core {
        case ["s3"]:
            // s3.amazonaws.com — legacy global, defaults to us-east-1
            region = "us-east-1"
        case let labels where labels.first == "s3" && labels.count >= 2:
            // s3.<region>.amazonaws.com
            region = String(labels[1])
        case let labels where labels.count == 1 && labels[0].hasPrefix("s3-"):
            // s3-<region>.amazonaws.com (legacy hyphen)
            region = String(labels[0].dropFirst(3))
        case let labels where labels.count >= 2 && labels[1] == "s3":
            // <bucket>.s3[.<region>].amazonaws.com
            bucket = String(labels[0])
            region = labels.count >= 3 ? String(labels[2]) : "us-east-1"
        case let labels where labels.count == 2 && labels[1].hasPrefix("s3-"):
            // <bucket>.s3-<region>.amazonaws.com (legacy hyphen + bucket)
            bucket = String(labels[0])
            region = String(labels[1].dropFirst(3))
        default:
            break
        }

        // Path-style endpoints carry the bucket as the first path segment.
        if bucket == nil {
            let firstPathSegment = url.path()
                .split(separator: "/")
                .first { !$0.isEmpty }
            if let firstPathSegment {
                bucket = String(firstPathSegment)
            }
        }

        return S3EndpointDetection(region: region, bucket: bucket)
    }
}
