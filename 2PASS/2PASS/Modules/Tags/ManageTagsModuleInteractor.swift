import Data
import Common
import UIKit

protocol ManageTagsModuleInteracting {
    func listAllTags() -> [ItemTagData]
    func deleteTag(tagID: ItemTagID)
    func getItemCountForTag(tagID: ItemTagID) -> Int
}

final class ManageTagsModuleInteractor: ManageTagsModuleInteracting {
    
    private let tagInteractor: TagInteracting
    private let itemsInteractor: ItemsInteracting
    private let syncChangeTriggerInteractor: SyncChangeTriggerInteracting
    
    init(
        tagInteractor: TagInteracting,
        itemsInteractor: ItemsInteracting,
        syncChangeTriggerInteractor: SyncChangeTriggerInteracting
    ) {
        self.tagInteractor = tagInteractor
        self.itemsInteractor = itemsInteractor
        self.syncChangeTriggerInteractor = syncChangeTriggerInteractor
    }
    
    func listAllTags() -> [ItemTagData] {
        tagInteractor.listAllTags()
    }
    
    func deleteTag(tagID: ItemTagID) {
        tagInteractor.deleteTag(tagID: tagID)
        tagInteractor.saveStorage()
        syncChangeTriggerInteractor.trigger()
    }
    
    func getItemCountForTag(tagID: ItemTagID) -> Int {
        itemsInteractor.getItemCountForTag(tagID: tagID)
    }
}

