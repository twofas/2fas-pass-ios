// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct VaultRecoveryEnterWordsView: View {

    @State
    var presenter: VaultRecoveryEnterWordsPresenter
    
    @Environment(\.dismiss)
    private var dismiss
    
    @FocusState
    private var focusedField: Int?
    
    var body: some View {
        VStack(spacing: 0) {
            List {
                Section {
                    list()
                        .alignmentGuide(.listRowSeparatorLeading) { _ in 38 }
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                } header: {
                    Text(T.restoreManualKeyInputDescription.localizedKey)
                        .padding(.top, 12)
                }
            }
            
            Button(T.commonContinue.localizedKey) {
                focusedField = nil
                presenter.onWordsSave()
            }
            .buttonStyle(.filled)
            .controlSize(.large)
            .disabled(presenter.canSaveWordsManually == false)
            .padding(.vertical, Spacing.l)
            .padding(.horizontal, Spacing.xl)
            .background(Color(UIColor.systemGroupedBackground))
        }
        .onAppear {
            focusedField = 1
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                ToolbarCancelButton {
                    dismiss()
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(T.restoreManualKeyInputTitle.localizedKey)
        .router(router: VaultRecoveryEnterWordsRouter(), destination: $presenter.destination)
    }
    
    @ViewBuilder
    private func list() -> some View {
        ForEach($presenter.words, id: \.id) { wordStorage in
            let index: Int = Int(wordStorage.wrappedValue.index) + 1
            
            LabeledContent {
                HStack {
                    TextField(T.restoreManualWord(index).localizedKey, text: wordStorage.word)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .focused($focusedField, equals: index)
                    
                    Spacer()
                    
                    if wordStorage.wrappedValue.isIncorrect {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.danger500)
                    } else if wordStorage.wrappedValue.word.isEmpty == false {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.success500)
                    }
                }
            } label: {
                Text("\(index)" as String)
                    .font(.subheadlineEmphasized)
                    .frame(width: 26, height: 26)
                    .background(Color.neutral100)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .labeledContentStyle(WordLabeledContentStyle())
    }
}

private struct WordLabeledContentStyle: LabeledContentStyle {
    
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Spacing.m) {
            configuration.label
            configuration.content
        }
    }
}
