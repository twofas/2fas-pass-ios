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
                    .textContentType(.name)
                    .focused($focusField, equals: .cardHolder)
            }
            .formFieldChanged(presenter.cardHolderChanged)

            LabeledInput(label: T.cardNumberLabel.localizedKey, fieldWidth: $fieldWidth) {
                PaymentCardNumberTextField(
                    T.cardNumberLabel,
                    text: $presenter.displayedCardNumber,
                    maxLength: presenter.maxCardNumberLength,
                    formatStyle: presenter.cardNumberFormatStyle,
                    isRevealed: $presenter.isCardNumberRevealed,
                    showRevealButton: presenter.isEditMode,
                    isInvalid: presenter.isCardNumberInvalid
                )
                .focused($focusField, equals: .cardNumber)
            }
            .formFieldChanged(presenter.cardNumberChanged)
            .onChange(of: presenter.isCardNumberRevealed, { oldValue, newValue in
                if newValue == false, focusField == .cardNumber {
                    focusField = nil
                }
            })
            .onChange(of: focusField) { oldValue, newValue in
                if newValue == .cardNumber {
                    presenter.revealCardNumber()
                    presenter.onCardNumberFocusChange(isFocused: true)
                } else if oldValue == .cardNumber {
                    presenter.onCardNumberFocusChange(isFocused: false)
                }
            }
            .onChange(of: presenter.cardNumber) { _, _ in
                presenter.onCardNumberChange()
            }

            LabeledInput(label: T.cardExpirationDateLabel.localizedKey, fieldWidth: $fieldWidth) {
                ExpirationDateField(
                    T.cardExpirationDatePlaceholder,
                    text: $presenter.expirationDate,
                    isInvalid: presenter.isExpirationDateInvalid
                )
                .textContentType(.creditCardExpiration)
                .focused($focusField, equals: .expirationDate)
            }
            .formFieldChanged(presenter.expirationDateChanged)
            .onChange(of: focusField) { oldValue, newValue in
                if newValue == .expirationDate {
                    presenter.onExpirationDateFocusChange(isFocused: true)
                } else if oldValue == .expirationDate {
                    presenter.onExpirationDateFocusChange(isFocused: false)
                }
            }
            .onChange(of: presenter.expirationDate) { _, _ in
                presenter.onExpirationDateChange()
            }

            LabeledInput(label: T.cardSecurityCodeLabel.localizedKey, fieldWidth: $fieldWidth) {
                SecureInput(label: T.cardSecurityCodeLabel, value: $presenter.displayedSecurityCode, isInvalid: presenter.isSecurityCodeInvalid)
                    .introspect { textField in
                        textField.keyboardType = .numberPad
                        textField.textContentType = .creditCardSecurityCode
                    }
                    .limitText($presenter.displayedSecurityCode, to: presenter.maxSecurityCodeLength)
                    .focused($focusField, equals: .securityCode)
            }
            .formFieldChanged(presenter.securityCodeChanged)
            .onChange(of: focusField) { oldValue, newValue in
                if newValue == .securityCode {
                    presenter.revealSecurityCode()
                    presenter.onSecurityCodeFocusChange(isFocused: true)
                } else if oldValue == .securityCode {
                    presenter.onSecurityCodeFocusChange(isFocused: false)
                }
            }
            .onChange(of: presenter.securityCode) { _, _ in
                presenter.onSecurityCodeChange()
            }
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
