// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Backup

/// Same surface as `BackupS3ConfigModuleInteracting` minus the "save"-side methods (recovery
/// only reads). Endpoint detection, normalization, and CSV import live here too — recovery
/// reuses the same UX affordances as the settings form (pasted AWS URL → autofill region/
/// bucket; CSV import → fill access keys).
@MainActor
protocol VaultRecoveryS3ModuleInteracting: AnyObject {

    /// Recovery's connectivity-and-access check: a successful `fetchIndex` is itself the
    /// validation, no separate `testConnection` probe is needed. Maps `BackupIndexFetchError`
    /// onto the recovery-presenter-facing `VaultRecoveryS3Error` cases.
    func recover(_ config: S3ServiceConfig) async throws(VaultRecoveryS3Error) -> BackupIndex

    func detect(endpoint: String) -> S3EndpointDetection?
    func normalize(endpoint: String) -> URL?
    func parseAccessKeysCSV(at url: URL) throws -> (accessKeyId: String, secretAccessKey: String)

    /// Strongly-typed recovery-config cache. JSON encoding and AES-GCM encryption-at-rest
    /// are both handled inside MainRepository (`MainRepositoryImpl+Backup.swift`'s
    /// recovery-cache pipeline, mirroring `saveBackupConfigs` on this type).
    var cachedConfig: S3ServiceConfig? { get }
    func cacheConfig(_ config: S3ServiceConfig)
}

@MainActor
final class VaultRecoveryS3ModuleInteractor: VaultRecoveryS3ModuleInteracting {

    private let recoveryInteractor: BackupSyncRecoveryInteracting
    private let uriInteractor: URIInteracting
    private let cacheInteractor: VaultRecoveryCacheInteracting

    init(
        recoveryInteractor: BackupSyncRecoveryInteracting,
        uriInteractor: URIInteracting,
        cacheInteractor: VaultRecoveryCacheInteracting
    ) {
        self.recoveryInteractor = recoveryInteractor
        self.uriInteractor = uriInteractor
        self.cacheInteractor = cacheInteractor
    }

    var cachedConfig: S3ServiceConfig? {
        cacheInteractor.cachedS3Config
    }

    func cacheConfig(_ config: S3ServiceConfig) {
        cacheInteractor.cacheS3Config(config)
    }

    func recover(_ config: S3ServiceConfig) async throws(VaultRecoveryS3Error) -> BackupIndex {
        do {
            return try await recoveryInteractor.fetchIndex(config)
        } catch {
            // Single `catch` + inner `switch` is the form Swift's typed-throws exhaustiveness
            // checker accepts (same idiom as `VaultRecoveryWebDAVModuleInteractor.recover`).
            switch error {
            case .transport(let transportError):
                // 404 here means "no index at this bucket yet" — distinct from the vault-fetch
                // 404 in `VaultRecoverySelectS3IndexModuleInteractor` ("vault disappeared from
                // bucket").
                if case .notFound = transportError {
                    throw VaultRecoveryS3Error.indexNotFound
                }
                throw VaultRecoveryS3Error.transport(transportError)
            case .indexIsDamaged:
                throw VaultRecoveryS3Error.indexIsDamaged
            }
        }
    }

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
            region = "us-east-1"
        case let labels where labels.first == "s3" && labels.count >= 2:
            region = String(labels[1])
        case let labels where labels.count == 1 && labels[0].hasPrefix("s3-"):
            region = String(labels[0].dropFirst(3))
        case let labels where labels.count >= 2 && labels[1] == "s3":
            bucket = String(labels[0])
            region = labels.count >= 3 ? String(labels[2]) : "us-east-1"
        case let labels where labels.count == 2 && labels[1].hasPrefix("s3-"):
            bucket = String(labels[0])
            region = String(labels[1].dropFirst(3))
        default:
            break
        }

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

    func normalize(endpoint: String) -> URL? {
        uriInteractor.normalizeURL(endpoint)
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

    private enum CSVParseError: Error {
        case malformed
    }
}
