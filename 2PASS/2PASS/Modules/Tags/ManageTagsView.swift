import SwiftUI
import CommonUI

struct ManageTagsView: View {
    
    @State
    var presenter: ManageTagsPresenter
    
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
            
            Button {
                presenter.addTag()
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "plus")
                    
                    Text(T.tagsAddNewCta.localizedKey)
                        .font(.body)
                    
                    Spacer()
                }
                .contentShape(Rectangle())
            }
        }
        .overlay {
            if presenter.tags.isEmpty {
                EmptyListView(Text(T.tagsEmptyList.localizedKey))
            }
        }
        .navigationTitle(T.tagsTitle.localizedKey)
        .navigationBarTitleDisplayMode(.inline)
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
