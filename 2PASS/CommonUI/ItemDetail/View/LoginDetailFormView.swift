// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct LoginDetailFormView: View {

    enum SelectedField: Hashable {
        case username
        case password
        case url(UUID)
    }

    let presenter: LoginDetailFormPresenter

    @State
    var selectedField: SelectedField?

    var body: some View {
        Group {
            ItemDetalFormTitle(name: presenter.name, icon: presenter.iconContent)

            if let username = presenter.username {
                ItemDetailFormActionsRow(
                    key: T.loginUsernameLabel.localizedKey,
                    value: { Text(username) },
                    actions: {[
                        UIAction(title: T.loginViewActionCopyUsername, handler: { _ in
                            presenter.onCopyUsername()
                        })
                    ]}
                )
                .selected($selectedField, equals: .username)
                .onChange(of: selectedField == .username) { oldValue, newValue in
                    if newValue {
                        presenter.onSelectUsername()
                    }
                }
            }

            if presenter.isPasswordAvailable, let password = presenter.password {
                ItemDetailFormActionsRow(
                    key: T.loginPasswordLabel.localizedKey,
                    value: {
                        SecureContainerView {
                            HStack {
                                Spacer()
                                Text(password).monospaced()
                            }
                        }
                    },
                    actions: {[
                        UIAction(title: T.loginViewActionCopyPassword, handler: { _ in
                            presenter.onCopyPassword()
                        })
                    ]}
                )
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
                            UIAction(title: T.loginViewActionOpenUri) { _ in
                                presenter.onOpenURI(uriNormalized)
                            }
                        ]},
                    )
                    .selected($selectedField, equals: .url(uri.id))
                }
            }

            ItemDetailFormProtectionLevel(presenter.protectionLevel)

            ItemDetailFormTags(presenter.tags)

            if let notes = presenter.notes, !notes.isEmpty {
                HStack {
                    Text(notes)
                        .multilineTextAlignment(.leading)
                        .font(.body)
                        .foregroundStyle(.neutral400)

                    Spacer(minLength: 0)
                }
            }
        }
        .onDisappear {
            presenter.onDisappear()
        }
    }
}
