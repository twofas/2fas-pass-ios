import SwiftUI
import Common
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
                        presenter.editTag(tag: tagItem)
                    },
                    onDelete: {
                        presenter.deleteTag(tag: tagItem)
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
        .scrollBounceBehavior(.basedOnSize)
        .onAppear {
            presenter.onAppear()
        }
        .router(router: ManageTagsRouter(), destination: $presenter.destination)
    }
}

#Preview {
    NavigationStack {
        ManageTagsView(
            presenter: .init(interactor: PreviewManageTagsModuleInteractor())
        )
    }
}

private struct PreviewManageTagsModuleInteractor: ManageTagsModuleInteracting {
    func listAllTags() -> [ItemTagData] {
        [
            ItemTagData(tagID: UUID(), vaultID: UUID(), name: "Work", color: .indigo, position: 0, modificationDate: Date()),
            ItemTagData(tagID: UUID(), vaultID: UUID(), name: "Personal", color: .green, position: 1, modificationDate: Date()),
            ItemTagData(tagID: UUID(), vaultID: UUID(), name: "Finance", color: .orange, position: 2, modificationDate: Date()),
            ItemTagData(tagID: UUID(), vaultID: UUID(), name: "Social", color: .cyan, position: 3, modificationDate: Date()),
            ItemTagData(tagID: UUID(), vaultID: UUID(), name: "Shopping", color: .purple, position: 4, modificationDate: Date())
        ]
    }

    func deleteTag(tagID: ItemTagID) {}

    func getItemCountForTag(tagID: ItemTagID) -> Int {
        Int.random(in: 1...15)
    }
}
