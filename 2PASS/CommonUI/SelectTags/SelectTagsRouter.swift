import SwiftUI
import Common

struct SelectTagsRouter: Router {
    
    static func buildView(
        selectedTags: [ItemTagData],
        onChanged: @escaping ([ItemTagData]) -> Void
    ) -> some View {
        SelectTagsView(
            presenter: SelectTagsPresenter(
                interactor: ModuleInteractorFactory.shared.selectTagsModuleInteractor(),
                selectedTags: selectedTags,
                onChange: onChanged
            )
        )
    }
    
    func view(for destination: SelectTagsDestination) -> some View {
        switch destination {
        case .addTag(let onClose):
            EditTagRouter.buildView(onClose: onClose)
        }
    }
    
    func routingType(for destination: SelectTagsDestination?) -> RoutingType? {
        switch destination {
        case .addTag:
            .sheet
        case nil:
            nil
        }
    }
}
