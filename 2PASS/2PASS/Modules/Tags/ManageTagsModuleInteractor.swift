import Data
import Common
import UIKit

protocol ManageTagsModuleInteracting {
    func listAllTags() -> [ItemTagData]
    func deleteTag(tagID: ItemTagID)
    func itemCountsByTag() -> [ItemTagID: Int]
}

final class ManageTagsModuleInteractor: ManageTagsModuleInteracting {

    private let tagInteractor: TagInteracting
    private let itemsInteractor: ItemsInteracting
    private let vaultsInteractor: VaultsInteracting
    private let syncTriggerInteractor: BackupSyncTriggerInteracting

    init(
        tagInteractor: TagInteracting,
        itemsInteractor: ItemsInteracting,
        vaultsInteractor: VaultsInteracting,
        syncTriggerInteractor: BackupSyncTriggerInteracting
    ) {
        self.tagInteractor = tagInteractor
        self.itemsInteractor = itemsInteractor
        self.vaultsInteractor = vaultsInteractor
        self.syncTriggerInteractor = syncTriggerInteractor
    }

    func listAllTags() -> [ItemTagData] {
        tagInteractor.listAllTags()
    }

    func deleteTag(tagID: ItemTagID) {
        guard let defaultVaultID = vaultsInteractor.defaultVaultID else { return }
        tagInteractor.deleteTag(tagID: tagID, in: defaultVaultID)
        tagInteractor.saveStorage()
        syncTriggerInteractor.syncAll()
    }
    
    func itemCountsByTag() -> [ItemTagID: Int] {
        itemsInteractor.itemCountsByTag()
    }
}

