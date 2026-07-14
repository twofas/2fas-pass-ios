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
    private let syncTriggerInteractor: BackupSyncTriggerInteracting

    init(
        tagInteractor: TagInteracting,
        vaultsInteractor: VaultsInteracting,
        syncTriggerInteractor: BackupSyncTriggerInteracting
    ) {
        self.tagInteractor = tagInteractor
        self.vaultsInteractor = vaultsInteractor
        self.syncTriggerInteractor = syncTriggerInteractor
    }

    func createTag(name: String, color: ItemTagColor) {
        guard let defaultVaultID = vaultsInteractor.defaultVaultID else { return }
        tagInteractor.createTag(name: name, color: color, in: defaultVaultID)
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
