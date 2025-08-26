import Common
import SwiftUI

enum SelectTagsDestination: RouterDestination {
    case addTag(onClose: Callback)
    
    var id: String {
        switch self {
        case .addTag: "addTag"
        }
    }
}

@Observable
final class SelectTagsPresenter {
    
    private let interactor: SelectTagsModuleInteracting
    private let _onChange: ([ItemTagData]) -> Void
    
    private(set) var tags: [ItemTagData] = []
    var selectedTags: [ItemTagData]
    var destination: SelectTagsDestination?
    
    init(
        interactor: SelectTagsModuleInteracting,
        selectedTags: [ItemTagData],
        onChange: @escaping ([ItemTagData]) -> Void
    ) {
        self.interactor = interactor
        self.selectedTags = selectedTags
        self._onChange = onChange
    }
    
    @MainActor
    func onAppear() {
        reload()
    }
    
    @MainActor
    func toggleTag(_ tag: ItemTagData) {
        if let index = selectedTags.firstIndex(of: tag) {
            selectedTags.remove(at: index)
        } else {
            selectedTags.append(tag)
        }
        
        selectedTags.sort { $0.name < $1.name }
        _onChange(selectedTags)
    }
    
    @MainActor
    func onAddNewTag() {
        destination = .addTag(onClose: { [weak self] in
            self?.destination = nil
            
            withAnimation {
                self?.reload()
            }
        })
    }
    
    @MainActor
    func isTagSelected(_ tag: ItemTagData) -> Bool {
        selectedTags.contains(where: { $0.tagID == tag.tagID })
    }
    
    private func reload() {
        tags = interactor.listAllTags()
    }
}
