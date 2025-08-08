import SwiftUI
import CommonUI

struct ManageTagsView: View {
    
    @State
    var presenter: ManageTagsPresenter

    @Environment(\.dismiss)
    private var dismiss
    
    var body: some View {
        List {
            ForEach(presenter.tags, id: \.tagID) { tagItem in
                ManageTagCell(
                    tag: tagItem,
                    onEdit: {
                        presenter.editTag(tagID: tagItem.tagID)
                    },
                    onDelete: {
                        presenter.deleteTag(tagID: tagItem.tagID)
                    }
                )
            }
        }
        .overlay {
            if presenter.tags.isEmpty {
                EmptyListView(
                    Text("You don't have any tags yet"),
                )
            }
        }
        .navigationTitle("Manage Tags")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(T.commonAdd.localizedKey) {
                    presenter.addTag()
                }
            }
        }
        .onAppear {
            presenter.onAppear()
        }
        .router(router: ManageTagsRouter(), destination: $presenter.destination)
    }
}

#Preview {
    ManageTagsView(
        presenter: .init(interactor:  ModuleInteractorFactory.shared.manageTagsModuleInteractor())
    )
}
