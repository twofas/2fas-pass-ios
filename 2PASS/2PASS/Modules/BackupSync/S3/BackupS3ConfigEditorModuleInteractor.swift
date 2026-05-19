// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup
import Data

@MainActor
protocol BackupS3ConfigEditorModuleInteracting: AnyObject {
    var existingConfig: S3ServiceConfig? { get }
    func testConnection(_ config: S3ServiceConfig) async throws(BackupFileServiceError)
    @discardableResult func save(_ config: S3ServiceConfig) -> BackupConfig.ID
    func detect(endpoint: String) -> S3EndpointDetection?
    func normalize(endpoint: String) -> URL?
    func parseAccessKeysCSV(at url: URL) throws -> (accessKeyId: String, secretAccessKey: String)
}

@MainActor
final class BackupS3ConfigEditorModuleInteractor: BackupS3ConfigEditorModuleInteracting {

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
        
        Task { try await syncTriggerInteractor.sync(id: id) }
        
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

    func parseAccessKeysCSV(at url: URL) throws -> (accessKeyId: String, secretAccessKey: String) {
        try configsInteractor.parseAccessKeysCSV(at: url)
    }
}
