import Data
import Common
import UIKit

protocol EditTagModuleInteracting {
    func createTag(name: String, color: ItemTagColor)
    func updateTag(tagID: ItemTagID, name: String, color: ItemTagColor)
    func getTag(tagID: ItemTagID) -> ItemTagData?
    func suggestNewColor() -> ItemTagColor
}

final class EditTagModuleInteractor: EditTagModuleInteracting {
    
    private let tagInteractor: TagInteracting
    private let syncTriggerInteractor: BackupSyncTriggerInteracting
    
    init(
        tagInteractor: TagInteracting,
        syncTriggerInteractor: BackupSyncTriggerInteracting
    ) {
        self.tagInteractor = tagInteractor
        self.syncTriggerInteractor = syncTriggerInteractor
    }
    
    func createTag(name: String, color: ItemTagColor) {
        tagInteractor.createTag(name: name, color: color)
        tagInteractor.saveStorage()
        syncTriggerInteractor.syncAll()
    }
    
    func updateTag(tagID: ItemTagID, name: String, color: ItemTagColor) {
        guard var tag = tagInteractor.getTag(for: tagID) else { return }
        tag.name = name
        tag.modificationDate = Date()
        tag.color = color
        tagInteractor.updateTag(data: tag)
        tagInteractor.saveStorage()
        syncTriggerInteractor.syncAll()
    }
    
    func getTag(tagID: ItemTagID) -> ItemTagData? {
        tagInteractor.getTag(for: tagID)
    }

    func suggestNewColor() -> ItemTagColor {
        tagInteractor.suggestedNewColor()
    }
}
