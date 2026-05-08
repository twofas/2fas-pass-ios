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
}

@MainActor
final class BackupS3ConfigModuleInteractor: BackupS3ConfigModuleInteracting {

    private let configsInteractor: BackupSyncConfigsInteracting
    private let uriInteractor: URIInteracting
    private let configID: UUID?

    init(
        configsInteractor: BackupSyncConfigsInteracting,
        uriInteractor: URIInteracting,
        configID: UUID?
    ) {
        self.configsInteractor = configsInteractor
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
        configsInteractor.addS3Config(config)
    }

    func saveUpdate(id: UUID, with config: S3ServiceConfig) {
        configsInteractor.updateS3Config(id: id, with: config)
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
}
