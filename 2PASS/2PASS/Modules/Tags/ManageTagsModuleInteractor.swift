import Data
import Common
import UIKit

protocol ManageTagsModuleInteracting {
    func listAllTags() -> [ItemTagData]
    func createTag(name: String)
    func deleteTag(tagID: ItemTagID)
    func getItemCountForTag(tagID: ItemTagID) -> Int
}

final class ManageTagsModuleInteractor: ManageTagsModuleInteracting {
    
    private let tagInteractor: TagInteracting
    private let passwordInteractor: PasswordInteracting
    
    init(tagInteractor: TagInteracting, passwordInteractor: PasswordInteracting) {
        self.tagInteractor = tagInteractor
        self.passwordInteractor = passwordInteractor
    }
    
    func listAllTags() -> [ItemTagData] {
        tagInteractor.listAllTags()
    }
    
    func createTag(name: String) {
        tagInteractor.createTag(name: name, color: .black)
        tagInteractor.saveStorage()
    }
    
    func deleteTag(tagID: ItemTagID) {
        tagInteractor.deleteTag(tagID: tagID)
        tagInteractor.saveStorage()
    }
    
    func getItemCountForTag(tagID: ItemTagID) -> Int {
        let allPasswords = passwordInteractor.listAllPasswords()
        return allPasswords.filter { password in
            password.tagIds?.contains(tagID) ?? false
        }.count
    }
}

