// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

private struct Constants {
    static let minHeightPassword: CGFloat = 60
    static let sheetHeight: CGFloat = 490
    static let sheetHeightLiquidGlass: CGFloat = 550
}

struct PasswordGeneratorView: View {

    @State
    var presenter: PasswordGeneratorPresenter
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading) {
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

                    Section {
                        Button(.passwordGeneratorUseCta) {
                            presenter.onUse()
                        }
                        .buttonStyle(.filled)
                        .controlSize(.large)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: Spacing.l, leading: 0, bottom: 0, trailing: 0))
                }
                .listSectionSpacing(Spacing.l)
                .contentMargins(.top, 0)
                .scrollBounceBehavior(.basedOnSize)
                .foregroundStyle(.mainText)
                .tint(.brand500)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarCancelButton {
                        presenter.onClose()
                    }
                }
            }
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
}

#Preview {
    Color.white
        .sheet(isPresented: .constant(true)) {
            PasswordGeneratorRouter.buildView(close: {}, closeUsePassword: { _ in })
        }
}
