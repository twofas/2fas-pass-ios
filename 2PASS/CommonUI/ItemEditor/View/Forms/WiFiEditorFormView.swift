// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct WiFiEditorFormView: View {

    enum Field: Hashable {
        case ssid
        case password
        case notes
    }

    @Bindable
    var presenter: WiFiEditorFormPresenter
    let resignFirstResponder: Callback

    @State
    private var fieldWidth: CGFloat?

    @FocusState
    private var focusField: Field?

    var body: some View {
        HStack {
            Spacer()
            ItemEditorIconView(content: .contentType(.wifi))
            Spacer()
        }
        .listRowBackground(Color.clear)

        Section {
            LabeledInput(label: String(localized: .wifiNameLabel), fieldWidth: $fieldWidth) {
                TextField(String(localized: .wifiNameLabel), text: $presenter.name)
            }
            .formFieldChanged(presenter.nameChanged)
        }
        .font(.body)
        .listSectionSpacing(Spacing.m)

        Section {
            LabeledInput(label: String(localized: .wifiSsidLabel), fieldWidth: $fieldWidth) {
                TextField(String(localized: .wifiSsidLabel), text: $presenter.ssid)
                    .focused($focusField, equals: .ssid)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            }
            .formFieldChanged(presenter.ssidChanged)

            LabeledInput(label: String(localized: .wifiPasswordLabel), fieldWidth: $fieldWidth) {
                SecureInput(label: .wifiPasswordLabel, value: $presenter.password)
                    .focused($focusField, equals: .password)
            }
            .formFieldChanged(presenter.passwordChanged)

            LabeledInput(label: String(localized: .wifiSecurityTypeLabel), fieldWidth: $fieldWidth) {
                Picker("", selection: $presenter.securityType) {
                    ForEach(WiFiContent.SecurityType.allCases, id: \.self) { securityType in
                        Text(securityType.formatted())
                            .tag(securityType)
                    }
                }
            }
            .formFieldChanged(presenter.securityTypeChanged)

            LabeledInput(label: String(localized: .wifiHiddenNetworkLabel), fieldWidth: $fieldWidth) {
                Toggle("", isOn: $presenter.hidden)
                    .tint(.accent)
            }
            .formFieldChanged(presenter.hiddenChanged)

        } header: {
            HStack {
                Text(.wifiNetworkHeader)
                Spacer()
                Button {
                    resignFirstResponder()
                    presenter.onScanQRCode()
                } label: {
                    Label(.wifiQrScanAction, systemImage: "qrcode.viewfinder")
                        .font(.bodyEmphasized)
                        .labelStyle(.button)
                }
            }
        }
        .font(.body)
        .listSectionSpacing(Spacing.m)

        ItemEditorProtectionLevelSection(presenter: presenter, resignFirstResponder: resignFirstResponder)
        ItemEditorTagsSection(presenter: presenter, resignFirstResponder: resignFirstResponder)

        ItemEditorNotesSection(
            notes: $presenter.notes,
            notesChanged: presenter.notesChanged,
            focusField: $focusField,
            focusedField: .notes,
            header: .wifiNotesLabel
        )
    }
}
