// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup
import Data

@MainActor
protocol BackupWebDAVConfigEditorModuleInteracting: AnyObject {
    var existingConfig: BackupWebDAVConfig? { get }
    func isSecureURL(_ url: URL) -> Bool
    func normalizeURL(_ str: String) -> URL?
    func testConnection(_ config: BackupWebDAVConfig) async throws(BackupFileServiceError)
    @discardableResult func save(_ config: BackupWebDAVConfig) -> BackupConfig.ID
}

@MainActor
final class BackupWebDAVConfigEditorModuleInteractor: BackupWebDAVConfigEditorModuleInteracting {

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

    func save(_ config: BackupWebDAVConfig) -> BackupConfig.ID {
        let id: BackupConfig.ID
        if let configID {
            configsInteractor.updateWebDAVConfig(id: configID, with: config)
            id = configID
        } else {
            id = configsInteractor.addWebDAVConfig(config)
        }
        
        Task {
            try await syncTriggerInteractor.sync(id: id)
        }
        
        return id
    }
}
