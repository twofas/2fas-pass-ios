// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct PaymentCardEditorFormView: View {

    enum Field: Hashable {
        case cardHolder
        case cardNumber
        case expirationDate
        case securityCode
        case notes
    }

    @Bindable
    var presenter: PaymentCardEditorFormPresenter
    let resignFirstResponder: Callback

    @State
    private var fieldWidth: CGFloat?

    @FocusState
    private var focusField: Field?

    private var paymentCardIcon: IconContent {
        if let icon = presenter.paymentCardIssuerIcon {
            return .icon(icon)
        }
        return .contentType(.paymentCard)
    }

    var body: some View {
        HStack {
            Spacer()
            ItemEditorIconView(content: paymentCardIcon)
            Spacer()
        }
        .listRowBackground(Color.clear)

        Section {
            LabeledInput(label: T.cardNameLabel.localizedKey, fieldWidth: $fieldWidth) {
                TextField(T.cardNameLabel.localizedKey, text: $presenter.name)
            }
            .formFieldChanged(presenter.nameChanged)
        }
        .font(.body)
        .listSectionSpacing(Spacing.m)

        Section {
            LabeledInput(label: T.cardHolderLabel.localizedKey, fieldWidth: $fieldWidth) {
                TextField(T.cardHolderLabel.localizedKey, text: $presenter.cardHolder)
                    .focused($focusField, equals: .cardHolder)
                    .textContentType(.name)
            }
            .formFieldChanged(presenter.cardHolderChanged)

            LabeledInput(label: T.cardNumberLabel.localizedKey, fieldWidth: $fieldWidth) {
                PaymentCardNumberField(
                    T.cardNumberLabel,
                    text: $presenter.cardNumber,
                    maxLength: presenter.maxCardNumberLength,
                    formatStyle: presenter.cardNumberFormatStyle
                )
                .focused($focusField, equals: .cardNumber)
            }
            .formFieldChanged(presenter.cardNumberChanged)

            LabeledInput(label: T.cardExpirationDateLabel.localizedKey, fieldWidth: $fieldWidth) {
                ExpirationDateField(T.cardExpirationDatePlaceholder, text: $presenter.expirationDate)
                    .textContentType(.creditCardExpiration)
                    .focused($focusField, equals: .expirationDate)
            }
            .formFieldChanged(presenter.expirationDateChanged)

            LabeledInput(label: T.cardSecurityCodeLabel.localizedKey, fieldWidth: $fieldWidth) {
                SecureInput(label: T.cardSecurityCodeLabel.localizedResource, value: $presenter.securityCode)
                    .introspect { textField in
                        textField.keyboardType = .numberPad
                        textField.textContentType = .creditCardSecurityCode
                    }
                    .limitText($presenter.securityCode, to: presenter.maxSecurityCodeLength)
                    .focused($focusField, equals: .securityCode)
            }
            .formFieldChanged(presenter.securityCodeChanged)
        } header: {
            Text(T.cardDetailsHeader.localizedKey)
        }
        .font(.body)
        .listSectionSpacing(Spacing.m)

        Section {
            TextField("", text: $presenter.notes, axis: .vertical)
                .focused($focusField, equals: .notes)
                .autocorrectionDisabled(false)
                .textInputAutocapitalization(.sentences)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 60, alignment: .topLeading)
                .contentShape(Rectangle())
                .formFieldChanged(presenter.notesChanged)
                .onTapGesture {
                    focusField = .notes
                }
        } header: {
            Text(T.cardNotesLabel.localizedKey)
        }
        .listSectionSpacing(Spacing.l)

        ItemEditorProtectionLevelSection(presenter: presenter, resignFirstResponder: resignFirstResponder)

        ItemEditorTagsSection(presenter: presenter, resignFirstResponder: resignFirstResponder)
    }
}
