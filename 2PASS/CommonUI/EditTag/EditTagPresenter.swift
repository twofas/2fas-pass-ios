import Foundation
import Common

@Observable @MainActor
final class EditTagPresenter {
    
    let limitNameLength: Int = Config.maxTagNameLength
    
    private let interactor: EditTagModuleInteracting
    private let onClose: Callback
    private let tagID: ItemTagID?
    
    var name: String = ""
    var selectedColor: ItemTagColor
    var isEditMode: Bool { tagID != nil }
    var navigationTitle: LocalizedStringResource { isEditMode ? .tagEditorEditTitle : .tagEditorNewTitle }

    init(interactor: EditTagModuleInteracting, tagID: ItemTagID? = nil, onClose: @escaping Callback) {
        self.interactor = interactor
        self.tagID = tagID
        self.onClose = onClose

        if let tagID, let tag = interactor.getTag(tagID: tagID) {
            self.name = tag.name
            self.selectedColor = tag.color.isUnknown ? .gray : tag.color
        } else {
            selectedColor = interactor.suggestNewColor()
        }
    }
    
    var canSave: Bool {
        name.isEmpty == false && name.count <= limitNameLength
    }

    func onSave() {
        guard !name.isEmpty else { return }

        if let tagID {
            interactor.updateTag(tagID: tagID, name: name, color: selectedColor)
        } else {
            interactor.createTag(name: name, color: selectedColor)
        }

        onClose()
    }
    
    func onCancel() {
        onClose()
    }
}
