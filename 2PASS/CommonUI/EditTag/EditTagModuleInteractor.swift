import Data
import Common
import UIKit

protocol EditTagModuleInteracting {
    func createTag(name: String)
    func updateTag(tagID: ItemTagID, name: String)
    func getTag(tagID: ItemTagID) -> ItemTagData?
}

final class EditTagModuleInteractor: EditTagModuleInteracting {
    
    private let tagInteractor: TagInteracting
    private let syncChangeTriggerInteractor: SyncChangeTriggerInteracting
    
    init(
        tagInteractor: TagInteracting,
        syncChangeTriggerInteractor: SyncChangeTriggerInteracting
    ) {
        self.tagInteractor = tagInteractor
        self.syncChangeTriggerInteractor = syncChangeTriggerInteractor
    }
    
    func createTag(name: String) {
        tagInteractor.createTag(name: name, color: .black)
        tagInteractor.saveStorage()
        syncChangeTriggerInteractor.trigger()
    }
    
    func updateTag(tagID: ItemTagID, name: String) {
        guard var tag = tagInteractor.getTag(for: tagID) else { return }
        tag.name = name
        tag.modificationDate = Date()
        tagInteractor.updateTag(data: tag)
        tagInteractor.saveStorage()
        syncChangeTriggerInteractor.trigger()
    }
    
    func getTag(tagID: ItemTagID) -> ItemTagData? {
        tagInteractor.getTag(for: tagID)
    }
}
