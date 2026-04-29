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
    func saveAdd(_ config: S3ServiceConfig)
    func saveUpdate(id: UUID, with config: S3ServiceConfig)
}

@MainActor
final class BackupS3ConfigModuleInteractor: BackupS3ConfigModuleInteracting {

    private let configsInteractor: BackupSyncConfigsInteracting
    private let configID: UUID?

    init(
        configsInteractor: BackupSyncConfigsInteracting,
        configID: UUID?
    ) {
        self.configsInteractor = configsInteractor
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
}
