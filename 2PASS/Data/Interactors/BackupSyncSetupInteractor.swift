// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Backup
import Common

public protocol BackupSyncInstalling: AnyObject {
    func initialize()
}

final class BackupSyncSetupInteractor: BackupSyncInstalling {
    private let mainRepository: MainRepository
    private let exportInteractor: ExportInteracting
    private let backupImportInteractor: BackupImportInteracting
    private let syncInteractor: SyncInteracting
    private let itemsInteractor: ItemsInteracting
    private let deletedItemsInteractor: DeletedItemsInteracting
    private let tagInteractor: TagInteracting

    init(
        mainRepository: MainRepository,
        exportInteractor: ExportInteracting,
        backupImportInteractor: BackupImportInteracting,
        syncInteractor: SyncInteracting,
        itemsInteractor: ItemsInteracting,
        deletedItemsInteractor: DeletedItemsInteracting,
        tagInteractor: TagInteracting
    ) {
        self.mainRepository = mainRepository
        self.exportInteractor = exportInteractor
        self.backupImportInteractor = backupImportInteractor
        self.syncInteractor = syncInteractor
        self.itemsInteractor = itemsInteractor
        self.deletedItemsInteractor = deletedItemsInteractor
        self.tagInteractor = tagInteractor
    }

    func initialize() {
        let adapter = BackupSyncAdapter(
            mainRepository: mainRepository,
            exportInteractor: exportInteractor,
            backupImportInteractor: backupImportInteractor,
            syncInteractor: syncInteractor
        )
        let cloudCacheStorage = CloudCacheStorageImpl(mainRepository: mainRepository)
        let encryptionHandler = EncryptionHandlerImpl(
            mainRepository: mainRepository,
            itemsInteractor: itemsInteractor,
            tagInteractor: tagInteractor
        )
        let localStorage = LocalStorageImpl(
            itemsInteractor: itemsInteractor,
            deletedItemsInteractor: deletedItemsInteractor,
            tagInteractor: tagInteractor,
            mainRepository: mainRepository
        )
        mainRepository.backupSyncContainer.setup(
            configStore: adapter,
            dateStore: adapter,
            context: adapter,
            vaultExporter: adapter,
            localMerger: adapter,
            awaitingFlags: adapter,
            localStorage: localStorage,
            cloudCacheStorage: cloudCacheStorage,
            encryptionHandler: encryptionHandler,
            currentDate: mainRepository.currentDate
        )
    }
}
