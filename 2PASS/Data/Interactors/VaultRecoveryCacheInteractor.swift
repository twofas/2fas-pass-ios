// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup

public protocol VaultRecoveryCacheInteracting: AnyObject {
    var cachedS3Config: S3ServiceConfig? { get }
    var cachedWebDAVConfig: BackupWebDAVConfig? { get }
    func cacheS3Config(_ config: S3ServiceConfig)
    func cacheWebDAVConfig(_ config: BackupWebDAVConfig)
    func clearCachedConfigs()
}

final class VaultRecoveryCacheInteractor {
    private let mainRepository: MainRepository

    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }
}

extension VaultRecoveryCacheInteractor: VaultRecoveryCacheInteracting {

    var cachedS3Config: S3ServiceConfig? {
        mainRepository.cachedS3RecoveryConfig
    }

    var cachedWebDAVConfig: BackupWebDAVConfig? {
        mainRepository.cachedWebDAVRecoveryConfig
    }

    func cacheS3Config(_ config: S3ServiceConfig) {
        mainRepository.saveCachedS3RecoveryConfig(config)
    }

    func cacheWebDAVConfig(_ config: BackupWebDAVConfig) {
        mainRepository.saveCachedWebDAVRecoveryConfig(config)
    }

    func clearCachedConfigs() {
        mainRepository.clearCachedRecoveryConfigs()
    }
}
