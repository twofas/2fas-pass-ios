import SwiftUI
import Common

struct EditTagView: View {
    
    @State
    var presenter: EditTagPresenter
    
    @FocusState
    private var isFocused: Bool
    
    @Environment(\.dismiss)
    private var dismiss
    
    var body: some View {
        GeometryReader { _ in
            VStack(spacing: 32) {
                VStack {
                    Text(presenter.navigationTitle)
                        .font(.title1Emphasized)
                        .foregroundStyle(.neutral950)
                    
                    Text(T.tagEditorDescription.localizedKey)
                        .font(.subheadline)
                        .foregroundStyle(.neutral600)
                }
                
                TextField(T.tagEditorPlaceholder.localizedKey, text: $presenter.name)
                    .focused($isFocused)
                    .padding(.horizontal, Spacing.l)
                    .frame(height: 44.0)
                    .background(Color.neutral50)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, Spacing.l)
                
                Button {
                    presenter.onSave()
                } label: {
                    Text(T.commonSave.localizedKey)
                }
                .disabled(presenter.name.isEmpty)
                .padding(.horizontal, Spacing.l)
                .buttonStyle(.filled)
                .controlSize(.large)
                
                Spacer()
            }
        }
        .padding(.top, Spacing.xxl4)
        .overlay(alignment: .topTrailing) {
            CloseButton {
                presenter.onCancel()
            }
            .padding(Spacing.l)
        }
        .presentationDetents([.height(270)])
        .presentationDragIndicator(.visible)
        .background(Color.base0)
        .onAppear {
            isFocused = true
        }
    }
}

#Preview {
    Color.white
        .sheet(isPresented: .constant(true)) {
            EditTagView(
                presenter: EditTagPresenter(
                    interactor: ModuleInteractorFactory.shared.editTagModuleInteractor(),
                    tagID: nil,
                    onClose: {}
                )
            )
        }
}
