// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import SwiftUIIntrospect

private struct Constants {
    static let minHeightPassword: CGFloat = 60
    static let sheetHeight: CGFloat = 490
    static let sheetHeightLiquidGlass: CGFloat = 550
}

struct PasswordGeneratorView: View {

    @State
    var presenter: PasswordGeneratorPresenter

    @State
    private var formContentHeight: CGFloat?
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                
                Form {
                    Section {
                        VStack {
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                
                                Text(presenter.password)
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .fontDesign(.monospaced)
                                
                                Spacer(minLength: 0)
                            }
                            .frame(minHeight: Constants.minHeightPassword)
                            
                            HStack(spacing: Spacing.xll) {
                                Button(Text(.passwordGeneratorCopyCta), symbol: Image(.copyActionIcon).renderingMode(.template)) {
                                    presenter.onCopy()
                                }
                                .buttonStyle(.bezeled)
                                
                                Button(Text(.passwordGeneratorGenerateCta), symbol: Image(.generateIcon).renderingMode(.template)) {
                                    presenter.onGenerate()
                                }
                                .buttonStyle(.bezeled)
                            }
                            .padding(.bottom, Spacing.s)
                        }
                    }
                    
                    Section {
                        HStack {
                            Text(.passwordGeneratorCharacters)
                            Spacer(minLength: 32)
                            Text(presenter.passwordLength, format: .number)
                                .monospaced()
                                .frame(width: 30, alignment: .trailing)
                            
                            Slider(
                                value: .convert($presenter.passwordLength),
                                in: (Float(presenter.minPasswordLength)...Float(presenter.maxPasswordLength)),
                                step: 1
                            )
                            .sensoryFeedback(.selection, trigger: presenter.passwordLength)
                        }
                        
                        Toggle(.passwordGeneratorDigits, isOn: $presenter.hasDigits)
                        Toggle(.passwordGeneratorUppercaseCharacters, isOn: $presenter.hasUppercase)
                        Toggle(.passwordGeneratorSpecialCharacters, isOn: $presenter.hasSpecial)
                    }
                }
                .frame(height: formContentHeight)
                .listSectionSpacing(Spacing.l)
                .contentMargins(.top, 0)
                .scrollBounceBehavior(.basedOnSize)
                .introspect(.form, on: .iOS(.v17, .v18, .v26)) { collectionView in
                    collectionView.layoutIfNeeded()
                    updateFormHeight(collectionView.contentSize.height)
                }
                
                Spacer()
                
                Button(.passwordGeneratorUseCta) {
                    presenter.onUse()
                }
                .buttonStyle(.filled)
                .controlSize(.large)
                .padding(Spacing.l)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarCancelButton {
                        presenter.onClose()
                    }
                }
            }
            .foregroundStyle(.mainText)
            .tint(.brand500)
            .toolbarTitleDisplayMode(.inline)
            .navigationTitle(.passwordGeneratorHeader)
        }
        .presentationDragIndicator(.hidden)
        .modify {
            if #available(iOS 26, *) {
                $0.presentationDetents([.height(Constants.sheetHeightLiquidGlass)])
            } else {
                $0.presentationDetents([.height(Constants.sheetHeight)])
            }
        }
        .onAppear {
            presenter.onAppear()
        }
    }

    private func updateFormHeight(_ contentHeight: CGFloat) {
        let measuredHeight = contentHeight
        guard measuredHeight > 0 else { return }

        Task { @MainActor in
            if formContentHeight != measuredHeight {
                formContentHeight = measuredHeight
            }
        }
    }
}

#Preview {
    Color.white
        .sheet(isPresented: .constant(true)) {
            PasswordGeneratorRouter.buildView(close: {}, closeUsePassword: { _ in })
        }
}
