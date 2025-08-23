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
    private let passwordInteractor: PasswordInteracting
    private let syncChangeTriggerInteractor: SyncChangeTriggerInteracting
    
    init(
        tagInteractor: TagInteracting,
        passwordInteractor: PasswordInteracting,
        syncChangeTriggerInteractor: SyncChangeTriggerInteracting
    ) {
        self.tagInteractor = tagInteractor
        self.passwordInteractor = passwordInteractor
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
        passwordInteractor.getItemCountForTag(tagID: tagID)
    }
}

