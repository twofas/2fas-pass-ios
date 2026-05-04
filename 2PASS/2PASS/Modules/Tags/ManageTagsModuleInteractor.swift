import Data
import Common
import UIKit

protocol ManageTagsModuleInteracting {
    func listAllTags() -> [ItemTagData]
    func deleteTag(tagID: ItemTagID)
    func getItemCountForTag(tagID: ItemTagID) -> Int

    func syncDidApplyRemoteChanges() -> AsyncStream<Void>
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
    
    func getItemCountForTag(tagID: ItemTagID) -> Int {
        itemsInteractor.getItemCountForTag(tagID: tagID, contentType: nil)
    }

    func syncDidApplyRemoteChanges() -> AsyncStream<Void> {
        syncTriggerInteractor.syncDidApplyRemoteChanges()
    }
}

