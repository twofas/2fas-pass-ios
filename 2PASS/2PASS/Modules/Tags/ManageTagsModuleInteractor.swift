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
    private let vaultsInteractor: VaultsInteracting
    private let syncChangeTriggerInteractor: SyncChangeTriggerInteracting

    init(
        tagInteractor: TagInteracting,
        itemsInteractor: ItemsInteracting,
        vaultsInteractor: VaultsInteracting,
        syncChangeTriggerInteractor: SyncChangeTriggerInteracting
    ) {
        self.tagInteractor = tagInteractor
        self.itemsInteractor = itemsInteractor
        self.vaultsInteractor = vaultsInteractor
        self.syncChangeTriggerInteractor = syncChangeTriggerInteractor
    }

    func listAllTags() -> [ItemTagData] {
        tagInteractor.listAllTags()
    }

    func deleteTag(tagID: ItemTagID) {
        guard let defaultVaultID = vaultsInteractor.defaultVaultID else { return }
        tagInteractor.deleteTag(tagID: tagID, in: defaultVaultID)
        tagInteractor.saveStorage()
        syncChangeTriggerInteractor.trigger()
    }
    
    func getItemCountForTag(tagID: ItemTagID) -> Int {
        itemsInteractor.getItemCountForTag(tagID: tagID, contentType: nil)
    }
}

