import Common
import SwiftUI
import CommonUI

enum ManageTagsDestination: RouterDestination {
    case addTag(onClose: Callback)
    case editTag(tagID: ItemTagID, onClose: Callback)
    case deleteConfirmation(tagName: String, onConfirm: Callback)
    
    var id: String {
        switch self {
        case .addTag: "addTag"
        case .editTag(let tagID, _): "editTag-\(tagID)"
        case .deleteConfirmation(let tagName, _): "deleteConfirmation-\(tagName)"
        }
    }
}

struct TagViewItem: Equatable {
    let tag: ItemTagData
    let itemCount: Int
    
    var tagID: ItemTagID { tag.tagID }
    var name: String { tag.name }
}

@Observable @MainActor
final class ManageTagsPresenter {

    private let interactor: ManageTagsModuleInteracting

    private(set) var tags: [TagViewItem] = []
    var destination: ManageTagsDestination?
    
    init(interactor: ManageTagsModuleInteracting) {
        self.interactor = interactor
    }
    
    func onAppear() {
        reload()
    }
    
    func addTag() {
        destination = .addTag(onClose: { [weak self] in
            self?.destination = nil
            
            withAnimation {
                self?.reload()
            }
        })
    }
    
    func editTag(tagID: ItemTagID) {
        destination = .editTag(tagID: tagID, onClose: { [weak self] in
            self?.destination = nil
            
            withAnimation {
                self?.reload()
            }
        })
    }
    
    func deleteTag(tagID: ItemTagID) {
        guard let tag = tags.first(where: { $0.tagID == tagID }) else { return }
        destination = .deleteConfirmation(tagName: tag.name, onConfirm: { [weak self] in
            self?.interactor.deleteTag(tagID: tagID)
            self?.destination = nil
            
            withAnimation {
                self?.reload()
            }
        })
    }
    
    private func reload() {
        let allTags = interactor.listAllTags()
        tags = allTags.map { tag in
            TagViewItem(
                tag: tag,
                itemCount: interactor.getItemCountForTag(tagID: tag.tagID)
            )
        }
    }
}
