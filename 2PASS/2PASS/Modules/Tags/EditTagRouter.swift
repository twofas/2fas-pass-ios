import SwiftUI
import CommonUI
import Common

struct EditTagRouter {
    
    @MainActor
    static func buildView(tagID: ItemTagID? = nil, onClose: @escaping Callback) -> some View {
        EditTagView(
            presenter: EditTagPresenter(
                interactor: ModuleInteractorFactory.shared.editTagModuleInteractor(),
                tagID: tagID,
                onClose: onClose
            )
        )
    }
}
