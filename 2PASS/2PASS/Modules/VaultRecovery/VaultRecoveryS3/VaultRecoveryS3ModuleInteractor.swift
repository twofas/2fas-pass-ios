// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Backup

@MainActor
protocol VaultRecoveryS3ModuleInteracting: AnyObject {

    func recover(_ config: S3ServiceConfig) async throws(VaultRecoveryS3Error) -> BackupIndex

    func detect(endpoint: String) -> S3EndpointDetection?
    func normalize(endpoint: String) -> URL?
    func parseAccessKeysCSV(at url: URL) throws -> (accessKeyId: String, secretAccessKey: String)

    var cachedConfig: S3ServiceConfig? { get }
    func cacheConfig(_ config: S3ServiceConfig)
}

@MainActor
final class VaultRecoveryS3ModuleInteractor: VaultRecoveryS3ModuleInteracting {

    private let recoveryInteractor: BackupSyncRecoveryInteracting
    private let configsInteractor: BackupSyncConfigsInteracting
    private let uriInteractor: URIInteracting
    private let cacheInteractor: VaultRecoveryCacheInteracting

    init(
        recoveryInteractor: BackupSyncRecoveryInteracting,
        configsInteractor: BackupSyncConfigsInteracting,
        uriInteractor: URIInteracting,
        cacheInteractor: VaultRecoveryCacheInteracting
    ) {
        self.recoveryInteractor = recoveryInteractor
        self.configsInteractor = configsInteractor
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
            switch error {
            case .transport(let transportError):
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
        configsInteractor.detectS3Endpoint(endpoint)
    }

    func normalize(endpoint: String) -> URL? {
        uriInteractor.normalizeURL(endpoint)
    }

    func parseAccessKeysCSV(at url: URL) throws -> (accessKeyId: String, secretAccessKey: String) {
        try configsInteractor.parseAccessKeysCSV(at: url)
    }
}
