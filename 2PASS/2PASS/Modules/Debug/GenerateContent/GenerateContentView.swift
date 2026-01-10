// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct GenerateContentView: View {
    @State
    private var presentWarning = false
    @State
    private var presentTagsWarning = false

    @Bindable
    var presenter: GenerateContentPresenter
    
    var body: some View {
        if presenter.isWorking {
            Text("Generating ..." as String)
            ProgressView()
                .progressViewStyle(.circular)
        } else {
            List {
                Section {
                    Text("Password count: \(presenter.itemsCount)" as String)
                }
                Section("Generate Additional Items" as String) {
                    PrimaryButton(title: "1") {
                        presenter.onGenerate(count: 1)
                    }
                    PrimaryButton(title: "5") {
                        presenter.onGenerate(count: 5)
                    }
                    PrimaryButton(title: "10") {
                        presenter.onGenerate(count: 10)
                    }
                    PrimaryButton(title: "50") {
                        presenter.onGenerate(count: 50)
                    }
                    PrimaryButton(title: "100") {
                        presenter.onGenerate(count: 100)
                    }
                    PrimaryButton(title: "1000") {
                        presenter.onGenerate(count: 1000)
                    }
                    PrimaryButton(title: "2000") {
                        presenter.onGenerate(count: 2000)
                    }
                    PrimaryButton(title: "5000") {
                        presenter.onGenerate(count: 5000)
                    }
                }
                .listRowBackground(Color.clear)
                
                Section {
                    Text("Secure Notes count: \(presenter.secureNotesCount)" as String)
                }
                Section("Generate Secure Notes" as String) {
                    PrimaryButton(title: "1") {
                        presenter.onGenerateSecureNote(count: 1)
                    }
                }
                .listRowBackground(Color.clear)

                Section {
                    Text("Unknown count: \(presenter.unknownCount)" as String)
                }
                Section("Generate Unknown" as String) {
                    PrimaryButton(title: "1") {
                        presenter.onGenerateUnknown(count: 1)
                    }
                }
                .listRowBackground(Color.clear)

                PrimaryButton(title: "Remove All Items") {
                    presentWarning = true
                }
                .padding(.vertical, Spacing.xl)
                .foregroundStyle(Asset.destructiveActionColor.swiftUIColor)

                Section {
                    Text("Tags count: \(presenter.tagsCount)" as String)
                }

                PrimaryButton(title: "Remove All Tags") {
                    presentTagsWarning = true
                }
                .padding(.vertical, Spacing.xl)
                .foregroundStyle(Asset.destructiveActionColor.swiftUIColor)
            }
            .onAppear {
                presenter.onAppear()
            }
            .scrollContentBackground(.hidden)
            .alert("Are you sure?" as String, isPresented: $presentWarning, actions: {
                Button("Remove all" as String, role: .destructive) {
                    presenter.onRemoveAllItems()
                }
                Button(.commonCancel, role: .cancel) {
                    presentWarning = false
                }
            })
            .alert("Remove all tags?" as String, isPresented: $presentTagsWarning, actions: {
                Button("Remove all" as String, role: .destructive) {
                    presenter.onRemoveAllTags()
                }
                Button(.commonCancel, role: .cancel) {
                    presentTagsWarning = false
                }
            })
            .listStyle(.grouped)
        }
    }
}
