// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup
import Data

@MainActor
protocol BackupS3ConfigModuleInteracting: AnyObject {
    var existingConfig: S3ServiceConfig? { get }
    func testConnection(_ config: S3ServiceConfig) async throws(BackupFileServiceError)
    @discardableResult func save(_ config: S3ServiceConfig) -> BackupConfig.ID
    func detect(endpoint: String) -> S3EndpointDetection?
    func normalize(endpoint: String) -> URL?
    func parseAccessKeysCSV(at url: URL) throws -> (accessKeyId: String, secretAccessKey: String)
}

private enum CSVParseError: Error {
    case malformed
}

@MainActor
final class BackupS3ConfigModuleInteractor: BackupS3ConfigModuleInteracting {

    private let configsInteractor: BackupSyncConfigsInteracting
    private let syncTriggerInteractor: BackupSyncTriggerInteracting
    private let uriInteractor: URIInteracting
    private let configID: BackupConfig.ID?

    init(
        configsInteractor: BackupSyncConfigsInteracting,
        syncTriggerInteractor: BackupSyncTriggerInteracting,
        uriInteractor: URIInteracting,
        configID: BackupConfig.ID?
    ) {
        self.configsInteractor = configsInteractor
        self.syncTriggerInteractor = syncTriggerInteractor
        self.uriInteractor = uriInteractor
        self.configID = configID
    }

    var existingConfig: S3ServiceConfig? {
        guard let configID else { return nil }
        for case .s3(let entry) in configsInteractor.allConfigs where entry.id == configID {
            return entry.config
        }
        return nil
    }

    func testConnection(_ config: S3ServiceConfig) async throws(BackupFileServiceError) {
        try await configsInteractor.test(config)
    }

    func save(_ config: S3ServiceConfig) -> BackupConfig.ID {
        let id: BackupConfig.ID
        if let configID {
            configsInteractor.updateS3Config(id: configID, with: config)
            id = configID
        } else {
            id = configsInteractor.addS3Config(config)
        }
        // Initial sync so the row immediately reflects "Syncing…" → "Last synced …"
        // instead of waiting for the next post-mutation `syncAll`.
        Task { try? await syncTriggerInteractor.sync(id: id) }
        return id
    }

    /// Canonicalizes the endpoint string the same way URIInteractor does for the rest of the app:
    /// trim whitespace, add `https://` scheme if missing, lowercase host, drop default ports,
    /// strip embedded credentials and trailing slashes/fragments. Returns `nil` for empty or
    /// unparseable input.
    func normalize(endpoint: String) -> URL? {
        uriInteractor.normalizeURL(endpoint)
    }

    func detect(endpoint: String) -> S3EndpointDetection? {
        configsInteractor.detectS3Endpoint(endpoint)
    }

    /// Parses an AWS-exported access keys CSV (header row: `Access key ID,Secret access key`).
    /// Tolerates BOM, CRLF/LF line endings, surrounding double-quotes, and case differences in
    /// header names. URL is security-scoped (returned by `fileImporter`), so access is bracketed.
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
