// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct EnterWordsInputListView: View {
    @State
    private var fieldWidth: CGFloat?
    
    @Bindable
    var presenter: EnterWordsPresenter
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Enter words from Recovery Kit manually" as String)
                    .font(.headline)
                    .padding(.bottom, 0)
                    .padding(.top, Spacing.m)
                Form {
                    Section {
                        list()
                    } header: {
                        EmptyView()
                    }
                    .listSectionSpacing(Spacing.l)
                }
                .padding(.top, 0)
                .formStyle(.grouped)
                
                PrimaryButton(title: T.commonContinue) {
                    presenter.onWordsSave()
                }
                .padding(Spacing.m)
            }
            .background {
                Color.backroundSecondary
                    .ignoresSafeArea()
            }
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        presenter.showEnterWords = false
                    } label: {
                        Text(T.commonCancel.localizedKey)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func list() -> some View {
        ForEach($presenter.words, id: \.id) { wordStorage in
            let index: Int = Int(wordStorage.wrappedValue.index) + 1
            let icon = Image(systemName: "\(index).circle.fill")
            IconInput(text: Text(icon), fieldWidth: $fieldWidth) {
                HStack {
                    TextField(T.restoreManualWord(index).localizedKey, text: wordStorage.word)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    
                    Spacer()
                        .frame(maxWidth: .infinity)
                    
                    if wordStorage.wrappedValue.isIncorrect {
                        Image(systemName: "exclamationmark.octagon.fill")
                            .foregroundStyle(Asset.destructiveActionColor.swiftUIColor)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
