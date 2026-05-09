// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup
import Data

struct S3EndpointDetection: Equatable {
    let region: String?
    let bucket: String?
}

@MainActor
protocol BackupS3ConfigModuleInteracting: AnyObject {
    var existingConfig: S3ServiceConfig? { get }
    func testConnection(_ config: S3ServiceConfig) async throws(BackupFileServiceError)
    func saveAdd(_ config: S3ServiceConfig)
    func saveUpdate(id: UUID, with config: S3ServiceConfig)
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
    private let configID: UUID?

    init(
        configsInteractor: BackupSyncConfigsInteracting,
        syncTriggerInteractor: BackupSyncTriggerInteracting,
        uriInteractor: URIInteracting,
        configID: UUID?
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

    func saveAdd(_ config: S3ServiceConfig) {
        let id = configsInteractor.addS3Config(config)
        // Initial sync so the row immediately reflects "Syncing…" → "Last synced …"
        // instead of waiting for the next post-mutation `syncAll`.
        Task { try? await syncTriggerInteractor.sync(id: id) }
    }

    func saveUpdate(id: UUID, with config: S3ServiceConfig) {
        configsInteractor.updateS3Config(id: id, with: config)
        
        Task { try? await syncTriggerInteractor.sync(id: id) }
    }

    /// Canonicalizes the endpoint string the same way URIInteractor does for the rest of the app:
    /// trim whitespace, add `https://` scheme if missing, lowercase host, drop default ports,
    /// strip embedded credentials and trailing slashes/fragments. Returns `nil` for empty or
    /// unparseable input.
    func normalize(endpoint: String) -> URL? {
        uriInteractor.normalizeURL(endpoint)
    }

    /// Best-effort parse of standard AWS S3 endpoint shapes. Returns `nil` for non-AWS hosts
    /// since S3-compatible providers (MinIO, Backblaze, R2) use ad-hoc URL shapes that aren't
    /// reliable to auto-parse. Input is normalized first (whitespace trim, scheme add, host
    /// lowercase) so the detection accepts permissive user typing.
    func detect(endpoint: String) -> S3EndpointDetection? {
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
