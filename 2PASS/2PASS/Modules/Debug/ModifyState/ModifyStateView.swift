// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct ModifyStateView: View {
    @Bindable
    var presenter: ModifyStatePresenter
    
    var body: some View {
        List {
            Section("DELETE" as String) {
                ForEach($presenter.list, id: \.self) { entry in
                    Toggle(entry.id.title, isOn: entry.isOn)
                        .disabled(!entry.wrappedValue.isEnabled)
                }
                PrimaryButton(title: "Reboot" as String) {
                    presenter.onReboot()
                }
                .padding(.vertical, Spacing.xl)
                .foregroundStyle(Asset.destructiveActionColor.swiftUIColor)
                .disabled(!presenter.rebootButtonEnabled)

            }
            Section {
                Button("Randomize AppKey" as String, role: .destructive) {
                    presenter.randomizeAppKey()
                }
                .buttonStyle(.filled)
                .controlSize(.large)
            }
            Section("CUSTOM" as String) {
                Toggle(
                    "Write decrypted copy of WebDAV backup" as String,
                    systemImage: "externaldrive.fill.badge.plus",
                    isOn: $presenter.writeDecryptedCopy
                )
            }
        }
        .listStyle(.plain)
        .onAppear {
            presenter.onAppear()
        }
    }
}
