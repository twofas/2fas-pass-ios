// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data

@MainActor
protocol BackupConfigsAddModuleInteracting: AnyObject {
    var canAddiCloud: Bool { get }
    @discardableResult func addiCloud() -> BackupConfig.ID?
}

@MainActor
final class BackupConfigsAddModuleInteractor: BackupConfigsAddModuleInteracting {

    private let configsInteractor: BackupSyncConfigsInteracting
    private let syncTriggerInteractor: BackupSyncTriggerInteracting

    init(
        configsInteractor: BackupSyncConfigsInteracting,
        syncTriggerInteractor: BackupSyncTriggerInteracting
    ) {
        self.configsInteractor = configsInteractor
        self.syncTriggerInteractor = syncTriggerInteractor
    }
    
    var canAddiCloud: Bool {
        configsInteractor.canAddiCloud
    }

    @discardableResult
    func addiCloud() -> BackupConfig.ID? {
        guard let id = configsInteractor.addiCloudConfig() else { return nil }
        
        Task {
            try await syncTriggerInteractor.sync(id: id)
        }
        
        return id
    }
}
