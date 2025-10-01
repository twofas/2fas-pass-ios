import Foundation
import Common

@Observable @MainActor
final class EditTagPresenter {
    
    let limitNameLength: Int = Config.maxTagNameLength
    
    private let interactor: EditTagModuleInteracting
    private let onClose: Callback
    private let tagID: ItemTagID?
    
    var name: String = ""
    var isEditMode: Bool { tagID != nil }
    var navigationTitle: String { isEditMode ? T.tagEditorEditTitle : T.tagEditorNewTitle }
    
    init(interactor: EditTagModuleInteracting, tagID: ItemTagID? = nil, onClose: @escaping Callback) {
        self.interactor = interactor
        self.tagID = tagID
        self.onClose = onClose
        
        if let tagID, let tag = interactor.getTag(tagID: tagID) {
            self.name = tag.name
        }        
    }
    
    var canSave: Bool {
        name.isEmpty == false && name.count <= limitNameLength
    }

    func onSave() {
        guard !name.isEmpty else { return }
        
        if let tagID {
            interactor.updateTag(tagID: tagID, name: name)
        } else {
            interactor.createTag(name: name)
        }
        
        onClose()
    }
    
    func onCancel() {
        onClose()
    }
}
