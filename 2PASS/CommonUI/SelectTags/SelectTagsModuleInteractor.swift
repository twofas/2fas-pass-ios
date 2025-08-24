import Data
import Common

protocol SelectTagsModuleInteracting {
    func listAllTags() -> [ItemTagData]
}

final class SelectTagsModuleInteractor: SelectTagsModuleInteracting {
    
    private let tagInteractor: TagInteracting
    
    init(tagInteractor: TagInteracting) {
        self.tagInteractor = tagInteractor
    }
    
    func listAllTags() -> [ItemTagData] {
        tagInteractor.listAllTags()
    }
}