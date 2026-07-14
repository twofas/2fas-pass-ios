import Common
import Data
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
    var color: ItemTagColor? { tag.color }
}

@Observable @MainActor
final class ManageTagsPresenter {

    private let interactor: ManageTagsModuleInteracting

    private(set) var tags: [TagViewItem] = []
    var destination: ManageTagsDestination?

    @ObservationIgnored
    private var storageDidChangeToken: Notifications.ObservationToken?

    init(interactor: ManageTagsModuleInteracting) {
        self.interactor = interactor
    }

    func onAppear() {
        reload()

        // Register synchronously so a save posted before the observer is live isn't dropped.
        // Rows show item counts, so item changes affect them too — not just tag changes.
        storageDidChangeToken?.cancel()
        storageDidChangeToken = NotificationCenter.default.addObserver(of: VaultDataDidChange.self) { [weak self] message in
            guard let self, message.affects([.items, .tags]) else { return }
            withAnimation {
                self.reload()
            }
        }
    }

    func onDisappear() {
        storageDidChangeToken?.cancel()
        storageDidChangeToken = nil
    }
    
    func addTag() {
        destination = .addTag(onClose: { [weak self] in
            self?.destination = nil
        })
    }

    func editTag(tag: TagViewItem) {
        destination = .editTag(tagID: tag.tagID, onClose: { [weak self] in
            self?.destination = nil
        })
    }

    func deleteTag(tag: TagViewItem) {
        destination = .deleteConfirmation(tagName: tag.name, onConfirm: { [weak self] in
            self?.interactor.deleteTag(tagID: tag.tagID)
            self?.destination = nil
        })
    }
    
    private func reload() {
        let allTags = interactor.listAllTags()
        let countsByTag = interactor.itemCountsByTag()
        tags = allTags.map { tag in
            TagViewItem(
                tag: tag,
                itemCount: countsByTag[tag.tagID] ?? 0
            )
        }
    }
}
