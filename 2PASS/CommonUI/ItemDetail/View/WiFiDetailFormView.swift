// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct WiFiDetailFormView: View {

    enum SelectedField: Hashable {
        case ssid
        case password
    }

    let presenter: WiFiDetailFormPresenter

    @State
    private var selectedField: SelectedField?

    var body: some View {
        ItemDetailSection {
            ItemDetailFormTitle(
                name: presenter.name,
                description: presenter.isHiddenNetwork ? String(localized: .wifiFieldHiddenValue) : nil,
                icon: .contentType(.wifi)
            )
            
            if let ssid = presenter.ssid {
                ItemDetailFormActionsRow(
                    key: .wifiSsidLabel,
                    value: { Text(ssid) },
                    actions: {[
                        UIAction(title: String(localized: .wifiViewActionCopySsid)) { _ in
                            presenter.onCopySSID()
                        }
                    ]}
                )
                .selected($selectedField, equals: .ssid)
                .onChange(of: selectedField == .ssid) { _, newValue in
                    if newValue {
                        presenter.onSelectSSID()
                    }
                }
            }
            
            if presenter.isPasswordAvailable, let password = presenter.password {
                ItemDetailFormActionsRow(
                    key: .wifiPasswordLabel,
                    value: {
                        SecureContainerView {
                            HStack {
                                Spacer()
                                Text(password).monospaced()
                            }
                        }
                    },
                    actions: {[
                        UIAction(title: String(localized: .wifiViewActionCopyPassword)) { _ in
                            presenter.onCopyPassword()
                        }
                    ]}
                )
                .selected($selectedField, equals: .password)
                .onChange(of: selectedField == .password) { _, newValue in
                    if newValue {
                        presenter.onSelectPassword()
                    }
                }
            }
            
            LabeledContent {
                Text(presenter.securityType.formatted())
            } label: {
                Text(.wifiSecurityTypeLabel)
            }
            .labeledContentStyle(.listCell)
            
            ItemDetailFormProtectionLevel(presenter.protectionLevel)
            ItemDetailFormNotes(presenter.notes)
        }
        .onAppear {
            selectedField = nil
        }
        
        if presenter.canShowNetworkQRCode {
            ItemDetailSection {
                Button {
                    presenter.onShowNetworkQRCode()
                } label: {
                    HStack {
                        Text(.wifiShowQrCodeAction)
                            .foregroundStyle(.accent)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.itemDetailRowHighlight)
            }
        }
    }
}
