import SwiftUI
import CommonUI

struct ManageTagsRouter: Router {

    @MainActor
    static func buildView() -> some View {
        NavigationStack {
            ManageTagsView(presenter: ManageTagsPresenter(interactor: ModuleInteractorFactory.shared.manageTagsModuleInteractor()))
        }
    }
    
    func routingType(for destination: ManageTagsDestination?) -> RoutingType? {
        switch destination {
        case .addTag, .editTag: .sheet
        case .deleteConfirmation(let tagName, _): 
            .alert(
                title: "Delete Tag",
                message: "Are you sure you want to delete \"\(tagName)\"? This action cannot be undone."
            )
        case nil: nil
        }
    }
    
    @MainActor
    func view(for destination: ManageTagsDestination) -> some View {
        switch destination {
        case .addTag(let onClose):
            EditTagRouter.buildView(tagID: nil, onClose: onClose)
        case .editTag(let tagID, let onClose):
            EditTagRouter.buildView(tagID: tagID, onClose: onClose)
        case .deleteConfirmation(_, let onConfirm):
            Group {
                Button("Delete", role: .destructive) {
                    onConfirm()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

