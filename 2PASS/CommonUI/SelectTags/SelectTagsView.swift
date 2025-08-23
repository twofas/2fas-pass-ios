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
                        Text(tag.name)
                            .font(.body)
                            .foregroundStyle(.primary)
                        
                        Spacer()
                                                   
                        Group {
                            if presenter.isTagSelected(tag) {
                                Image(systemName: "checkmark.circle.fill")
                                    .resizable()
                                    .foregroundStyle(.accent)
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
    SelectTagsView(
        presenter: SelectTagsPresenter(
            interactor: ModuleInteractorFactory.shared.selectTagsModuleInteractor(),
            selectedTags: [],
            onChange: { _ in }
        )
    )
}
