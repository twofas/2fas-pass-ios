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

/// CRUD-style access to backup-sync configs, plus a connection probe. Orchestrated sync
/// lives in `BackupSyncTriggerInteracting`.
public protocol BackupSyncConfigsInteracting: AnyObject {
    var allConfigs: [BackupConfig] { get }

    @discardableResult
    func addWebDAVConfig(_ config: BackupWebDAVConfig) -> BackupConfig.ID

    @discardableResult
    func addS3Config(_ config: S3ServiceConfig) -> BackupConfig.ID

    /// Adds the iCloud backend; returns the assigned id, or `nil` if one already exists.
    /// Single-instance: only one CloudKit container per build.
    @discardableResult
    func addiCloudConfig() -> BackupConfig.ID?

    /// `true` when no iCloud entry exists yet. UI affordance — the authoritative check is
    /// inside `addiCloudConfig()`.
    var canAddiCloud: Bool { get }

    /// Replaces the config bound to `id`, preserving id and `createdAt`. No-op if the id
    /// doesn't exist or maps to a different kind.
    func updateWebDAVConfig(id: BackupConfig.ID, with config: BackupWebDAVConfig)
    func updateS3Config(id: BackupConfig.ID, with config: S3ServiceConfig)

    func removeConfig(id: BackupConfig.ID)

    /// Emits once per successful add / update / remove.
    var configsDidChange: Notifications.MessageSequence<BackupConfigsDidChange> { get }

    /// Auth + index-read probe. Returns silently on success including the "no index yet"
    /// 404 (folded into success).
    func test(_ config: BackupWebDAVConfig) async throws(BackupFileServiceError)
    func test(_ config: S3ServiceConfig) async throws(BackupFileServiceError)

    /// Best-effort parse of standard AWS S3 endpoint shapes. Returns `nil` for non-AWS
    /// hosts (S3-compatible providers use ad-hoc URL shapes).
    func detectS3Endpoint(_ endpoint: String) -> S3EndpointDetection?

    /// Parses an AWS-exported access keys CSV. Tolerates BOM, CRLF/LF, surrounding quotes,
    /// and header case. URL is security-scoped (`fileImporter`), bracketed inside.
    func parseAccessKeysCSV(at url: URL) throws -> (accessKeyId: String, secretAccessKey: String)
}

private enum CSVParseError: Error {
    case malformed
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

    var canAddiCloud: Bool {
        !allConfigs.hasICloud
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

    func parseAccessKeysCSV(at url: URL) throws -> (accessKeyId: String, secretAccessKey: String) {
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }

        var contents = try String(contentsOf: url, encoding: .utf8)
        if contents.first == "\u{FEFF}" {
            contents.removeFirst()
        }

        let nonEmptyLines = contents
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        guard nonEmptyLines.count >= 2 else { throw CSVParseError.malformed }

        let parseRow: (String) -> [String] = { line in
            line.split(separator: ",", omittingEmptySubsequences: false).map { cell in
                var value = cell.trimmingCharacters(in: .whitespaces)
                if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                    value = String(value.dropFirst().dropLast())
                }
                return value
            }
        }

        let headers = parseRow(nonEmptyLines[0]).map { $0.lowercased() }
        let values = parseRow(nonEmptyLines[1])

        guard
            let accessKeyIndex = headers.firstIndex(of: "access key id"),
            let secretKeyIndex = headers.firstIndex(of: "secret access key"),
            accessKeyIndex < values.count,
            secretKeyIndex < values.count
        else { throw CSVParseError.malformed }

        let accessKey = values[accessKeyIndex].trimmingCharacters(in: .whitespaces)
        let secretKey = values[secretKeyIndex].trimmingCharacters(in: .whitespaces)
        guard !accessKey.isEmpty, !secretKey.isEmpty else { throw CSVParseError.malformed }

        return (accessKey, secretKey)
    }
}
