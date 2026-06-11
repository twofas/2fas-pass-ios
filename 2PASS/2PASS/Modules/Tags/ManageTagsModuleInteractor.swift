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
    private let syncTriggerInteractor: BackupSyncTriggerInteracting
    
    init(
        tagInteractor: TagInteracting,
        itemsInteractor: ItemsInteracting,
        syncTriggerInteractor: BackupSyncTriggerInteracting
    ) {
        self.tagInteractor = tagInteractor
        self.itemsInteractor = itemsInteractor
        self.syncTriggerInteractor = syncTriggerInteractor
    }
    
    func listAllTags() -> [ItemTagData] {
        tagInteractor.listAllTags()
    }
    
    func deleteTag(tagID: ItemTagID) {
        tagInteractor.deleteTag(tagID: tagID)
        tagInteractor.saveStorage()
        syncTriggerInteractor.syncAll()
    }
    
    func itemCountsByTag() -> [ItemTagID: Int] {
        itemsInteractor.itemCountsByTag()
    }
}

