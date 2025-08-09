import SwiftUI
import Common

public struct EditTagRouter {
    
    @MainActor
    public static func buildView(tagID: ItemTagID? = nil, onClose: @escaping Callback) -> some View {
        EditTagView(
            presenter: EditTagPresenter(
                interactor: ModuleInteractorFactory.shared.editTagModuleInteractor(),
                tagID: tagID,
                onClose: onClose
            )
        )
    }
}
