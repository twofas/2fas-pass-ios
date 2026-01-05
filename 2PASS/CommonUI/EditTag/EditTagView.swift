import SwiftUI
import SwiftUIIntrospect
import UIKit
import Common

private struct Constants {
    static let sheetHeightPhone = 300.0
    static let sheetHeightPad = 340.0
    static let textFieldHeight = 44.0
    static let textFieldCornerRadius = 10.0
}

struct EditTagView: View {
    
    @State
    var presenter: EditTagPresenter
    
    @FocusState
    private var isFocused: Bool

    @State
    private var didFocus = false

    @Environment(\.dismiss)
    private var dismiss

    private var isPad: Bool {
        UIDevice.isiPad
    }
    
    var body: some View {
        GeometryReader { _ in
            VStack(spacing: Spacing.xll3) {
                VStack {
                    Text(presenter.navigationTitle)
                        .font(.title1Emphasized)
                        .foregroundStyle(.neutral950)
                    
                    Text(T.tagEditorDescription.localizedKey)
                        .font(.subheadline)
                        .foregroundStyle(.neutral600)
                }
                
                VStack(spacing: Spacing.l) {
                    HStack(spacing: Spacing.s) {
                        TextField(T.tagEditorPlaceholder.localizedKey, text: $presenter.name)
                            .focused($isFocused)
                            .onChange(of: presenter.name) { _, newValue in
                                if newValue.count > presenter.limitNameLength {
                                    presenter.name = String(newValue.prefix(presenter.limitNameLength))
                                }
                            }
                            .onSubmit {
                                presenter.onSave()
                            }
                            .introspect(.textField, on: .iOS(.v17, .v18, .v26)) { textField in
                                guard !didFocus else { return }
                                didFocus = true
                                Task { @MainActor in
                                    textField.becomeFirstResponder()
                                }
                            }
                        
                        Circle()
                            .fill(Color(UIColor(presenter.selectedColor)))
                            .frame(width: ItemTagColorMetrics.regular.size, height: ItemTagColorMetrics.regular.size)
                    }
                    .padding(.horizontal, Spacing.l)
                    .frame(height: Constants.textFieldHeight)
                    .background(Color.neutral50)
                    .clipShape(RoundedRectangle(cornerRadius: Constants.textFieldCornerRadius))
                    .padding(.horizontal, Spacing.l)
                    
                    HStack {
                        ForEach(ItemTagColor.allKnownCases, id: \.self) { color in
                            let tagColor = Color(UIColor(color))
                            Button {
                                presenter.selectedColor = color
                            } label: {
                                Circle()
                                    .fill(tagColor)
                                    .frame(width: ItemTagColorMetrics.large.size, height: ItemTagColorMetrics.large.size)
                                    .padding(4)
                                    .overlay {
                                        if presenter.selectedColor == color {
                                            Circle()
                                                .stroke(tagColor, lineWidth: 2)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.horizontal, Spacing.l)
                }
                
                Button {
                    presenter.onSave()
                } label: {
                    Text(T.commonSave.localizedKey)
                }
                .disabled(presenter.canSave == false)
                .padding(.horizontal, Spacing.l)
                .buttonStyle(.filled)
                .controlSize(.large)
            }
            .padding(.top, Spacing.xxl4)
            .padding(.bottom, Spacing.l)
        }
        .overlay(alignment: .topTrailing) {
            CloseButton {
                presenter.onCancel()
            }
            .padding(Spacing.l)
        }
        .presentationDetents([.height(isPad ? Constants.sheetHeightPad : Constants.sheetHeightPhone)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.base0)
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
