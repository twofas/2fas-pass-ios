// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup
import Data

@MainActor
protocol BackupConfigsAddModuleInteracting: AnyObject {
    var canAddiCloud: Bool { get }
    @discardableResult func addiCloud() -> UUID?
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
        !configsInteractor.allConfigs.contains { $0.kind == .iCloud }
    }

    @discardableResult
    func addiCloud() -> UUID? {
        // Persisting the iCloud config is the enable signal — the container's
        // `saveConfigs(_:)` diff calls `cloudSync.enable()` internally. After enable, kick
        // an initial sync so any existing local vault state is pushed up to iCloud
        // immediately rather than waiting for the next post-mutation `syncAll`.
        guard let id = configsInteractor.addiCloudConfig() else { return nil }
        Task { try? await syncTriggerInteractor.sync(id: id) }
        return id
    }
}
