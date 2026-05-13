// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup
import Data

@MainActor
protocol BackupWebDAVConfigModuleInteracting: AnyObject {
    var existingConfig: BackupWebDAVConfig? { get }
    func isSecureURL(_ url: URL) -> Bool
    func normalizeURL(_ str: String) -> URL?
    func testConnection(_ config: BackupWebDAVConfig) async throws(BackupFileServiceError)
    @discardableResult
    func saveAdd(_ config: BackupWebDAVConfig) -> BackupConfig.ID
    func saveUpdate(id: BackupConfig.ID, with config: BackupWebDAVConfig)
}

@MainActor
final class BackupWebDAVConfigModuleInteractor: BackupWebDAVConfigModuleInteracting {

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

    var existingConfig: BackupWebDAVConfig? {
        guard let configID else { return nil }
        for case .webDAV(let entry) in configsInteractor.allConfigs where entry.id == configID {
            return entry.config
        }
        return nil
    }

    func isSecureURL(_ url: URL) -> Bool {
        uriInteractor.isSecureURL(url)
    }

    func normalizeURL(_ str: String) -> URL? {
        uriInteractor.normalizeURL(str, options: .trailingSlash)
    }

    func testConnection(_ config: BackupWebDAVConfig) async throws(BackupFileServiceError) {
        try await configsInteractor.test(config)
    }

    func saveAdd(_ config: BackupWebDAVConfig) -> BackupConfig.ID {
        let id = configsInteractor.addWebDAVConfig(config)
        // Initial sync so the row immediately reflects "Syncing…" → "Last synced …"
        // instead of waiting for the next post-mutation `syncAll`.
        Task { try? await syncTriggerInteractor.sync(id: id) }
        return id
    }

    func saveUpdate(id: BackupConfig.ID, with config: BackupWebDAVConfig) {
        configsInteractor.updateWebDAVConfig(id: id, with: config)
        
        Task { try? await syncTriggerInteractor.sync(id: id) }
    }
}
