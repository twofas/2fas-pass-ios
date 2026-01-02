import SwiftUI
import Common

struct SelectTagsView: View {
    
    @State
    var presenter: SelectTagsPresenter
    
    @Environment(\.dismiss)
    private var dismiss
    
    var body: some View {
        List {
            ForEach(presenter.tags, id: \.tagID) { tag in
                Button {
                    presenter.toggleTag(tag)
                } label: {
                    HStack {
                        TagContentCell(
                            name: Text(tag.name),
                            color: tag.color
                        )
                        
                        Spacer()
                                                   
                        Group {
                            if presenter.isTagSelected(tag) {
                                Image(systemName: "checkmark.circle.fill")
                                    .resizable()
                                    .foregroundStyle(.white, .accent)
                            } else {
                                Circle()
                                    .stroke(Color.neutral200)
                            }
                        }
                        .frame(width: 20, height: 20)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            
            Button {
                presenter.onAddNewTag()
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
        .navigationBarTitleDisplayMode(.inline)
        .scrollBounceBehavior(.basedOnSize)
        .onAppear {
            presenter.onAppear()
        }
        .router(router: SelectTagsRouter(), destination: $presenter.destination)
    }
}

#Preview {
    NavigationStack {
        SelectTagsView(
            presenter: SelectTagsPresenter(
                interactor: PreviewSelectTagsModuleInteractor(),
                selectedTags: [],
                onChange: { _ in }
            )
        )
    }
}

private final class PreviewSelectTagsModuleInteractor: SelectTagsModuleInteracting {
    func listAllTags() -> [ItemTagData] {
        [
            ItemTagData(tagID: UUID(), vaultID: UUID(), name: "Work", color: .indigo, position: 0, modificationDate: Date()),
            ItemTagData(tagID: UUID(), vaultID: UUID(), name: "Personal", color: .green, position: 1, modificationDate: Date()),
            ItemTagData(tagID: UUID(), vaultID: UUID(), name: "Finance", color: .orange, position: 2, modificationDate: Date()),
            ItemTagData(tagID: UUID(), vaultID: UUID(), name: "Social", color: .cyan, position: 3, modificationDate: Date()),
            ItemTagData(tagID: UUID(), vaultID: UUID(), name: "Shopping", color: .purple, position: 4, modificationDate: Date())
        ]
    }
}
