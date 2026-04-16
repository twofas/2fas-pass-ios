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
    private let vaultsInteractor: VaultsInteracting
    private let syncChangeTriggerInteractor: SyncChangeTriggerInteracting

    init(
        tagInteractor: TagInteracting,
        vaultsInteractor: VaultsInteracting,
        syncChangeTriggerInteractor: SyncChangeTriggerInteracting
    ) {
        self.tagInteractor = tagInteractor
        self.vaultsInteractor = vaultsInteractor
        self.syncChangeTriggerInteractor = syncChangeTriggerInteractor
    }

    func createTag(name: String, color: ItemTagColor) {
        guard let defaultVaultID = vaultsInteractor.defaultVaultID else { return }
        tagInteractor.createTag(name: name, color: color, in: defaultVaultID)
        tagInteractor.saveStorage()
        syncChangeTriggerInteractor.trigger()
    }
    
    func updateTag(tagID: ItemTagID, name: String, color: ItemTagColor) {
        guard var tag = tagInteractor.getTag(for: tagID) else { return }
        tag.name = name
        tag.modificationDate = Date()
        tag.color = color
        tagInteractor.updateTag(data: tag)
        tagInteractor.saveStorage()
        syncChangeTriggerInteractor.trigger()
    }
    
    func getTag(tagID: ItemTagID) -> ItemTagData? {
        tagInteractor.getTag(for: tagID)
    }

    func suggestNewColor() -> ItemTagColor {
        tagInteractor.suggestedNewColor()
    }
}
