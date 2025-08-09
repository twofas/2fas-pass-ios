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
    
    init(tagInteractor: TagInteracting) {
        self.tagInteractor = tagInteractor
    }
    
    func createTag(name: String) {
        tagInteractor.createTag(name: name, color: .black)
        tagInteractor.saveStorage()
    }
    
    func updateTag(tagID: ItemTagID, name: String) {
        guard var tag = tagInteractor.getTag(for: tagID) else { return }
        tag.name = name
        tag.modificationDate = Date()
        tagInteractor.updateTag(data: tag)
        tagInteractor.saveStorage()
    }
    
    func getTag(tagID: ItemTagID) -> ItemTagData? {
        tagInteractor.getTag(for: tagID)
    }
}
