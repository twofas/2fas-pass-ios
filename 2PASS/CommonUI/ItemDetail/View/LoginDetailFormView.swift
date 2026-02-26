// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct LoginDetailFormView: View {

    enum SelectedField: Hashable {
        case username
        case password
        case url(UUID)
    }

    let presenter: LoginDetailFormPresenter

    @State
    var selectedField: SelectedField?
    
    private var isTextToInsertMode: Bool {
        if #available(iOS 18.0, *) {
            presenter.autoFillEnvironment?.isTextToInsert == true
        } else {
            false
        }
    }

    var body: some View {
        ItemDetailSection {
            ItemDetailFormTitle(name: presenter.name, icon: presenter.iconContent)

            if let username = presenter.username {
                ItemDetailFormActionsRow(
                    key: .loginUsernameLabel,
                    value: { Text(username) },
                    actions: {[
                        UIAction(title: String(localized: .loginViewActionCopyUsername), handler: { _ in
                            presenter.onCopyUsername()
                        })
                    ]}
                )
                .showValueAsButton(isTextToInsertMode)
                .selected($selectedField, equals: .username)
                .onChange(of: selectedField == .username) { oldValue, newValue in
                    if newValue {
                        presenter.onSelectUsername()
                    }
                }
            }

            if presenter.isPasswordAvailable, let password = presenter.password {
                ItemDetailFormActionsRow(
                    key: .loginPasswordLabel,
                    value: {
                        SecureContainerView {
                            HStack {
                                Spacer()
                                Text(password)
                                    .monospaced()
                                    .multilineTextAlignment(.leading)
                            }
                        }
                    },
                    actions: {[
                        UIAction(title: String(localized: .loginViewActionCopyPassword), handler: { _ in
                            presenter.onCopyPassword()
                        })
                    ]}
                )
                .showValueAsButton(isTextToInsertMode)
                .selected($selectedField, equals: .password)
                .onChange(of: selectedField == .password) { oldValue, newValue in
                    if newValue {
                        presenter.onSelectPassword()
                    }
                }
            }

            ForEach(Array(presenter.uri.filter({ $0.uriNormalized != nil }).enumerated()), id: \.element.id) { index, uri in
                if let uriNormalized = uri.uriNormalized {
                ItemDetailFormActionsRow(
                    key: presenter.uriKey(at: index),
                    value: { Text(uri.uri.withZeroWidthSpaces) },
                    actions: {[
                        UIAction(title: String(localized: .loginViewActionOpenUri)) { _ in
                                presenter.onOpenURI(uriNormalized)
                            },
                            UIAction(title: String(localized: .loginViewActionCopyUri)) { _ in
                                presenter.onCopyURI(uriNormalized)
                            }
                        ]}
                    )
                    .selected($selectedField, equals: .url(uri.id))
                }
            }

            ItemDetailFormProtectionLevel(presenter.protectionLevel)
            ItemDetailFormNotes(presenter.notes)
        }
        .onAppear {
            selectedField = nil
        }
        .onAppear {
            selectedField = nil
        }
        .onDisappear {
            presenter.onDisappear()
        }
    }
}
