// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct PaymentCardDetailFormView: View {

    enum SelectedField: Hashable {
        case cardHolder
        case cardNumber
        case expirationDate
        case securityCode
    }

    let presenter: PaymentCardDetailFormPresenter

    @State
    private var selectedField: SelectedField?

    var body: some View {
        Group {
            ItemDetailFormTitle(name: presenter.name, icon: presenter.paymentCardIcon)

            if let cardHolder = presenter.cardHolder {
                ItemDetailFormActionsRow(
                    key: T.cardHolderLabel.localizedKey,
                    value: { Text(cardHolder) },
                    actions: {[
                        UIAction(title: T.cardViewActionCopyCardHolder) { _ in
                            presenter.onCopyCardHolder()
                        }
                    ]}
                )
                .selected($selectedField, equals: .cardHolder)
            }

            if let cardNumber = presenter.cardNumber {
                ItemDetailFormActionsRow(
                    key: T.cardNumberLabel.localizedKey,
                    value: {
                        SecureContainerView {
                            HStack {
                                Spacer()
                                Text(cardNumber)
                                    .monospaced()
                                    .multilineTextAlignment(.leading)
                            }
                        }
                    },
                    actions: {[
                        UIAction(title: T.cardViewActionCopyCardNumber) { _ in
                            presenter.onCopyCardNumber()
                        }
                    ]}
                )
                .selected($selectedField, equals: .cardNumber)
                .onChange(of: selectedField == .cardNumber) { _, newValue in
                    if newValue {
                        presenter.onSelectCardNumber()
                    }
                }
            }

            if let expirationDate = presenter.expirationDate {
                ItemDetailFormActionsRow(
                    key: T.cardExpirationDateLabel.localizedKey,
                    value: { Text(expirationDate) },
                    actions: {[
                        UIAction(title: T.cardViewActionCopyExpirationDate) { _ in
                            presenter.onCopyExpirationDate()
                        }
                    ]}
                )
                .selected($selectedField, equals: .expirationDate)
            }

            if let securityCode = presenter.securityCode {
                ItemDetailFormActionsRow(
                    key: T.cardSecurityCodeLabel.localizedKey,
                    value: {
                        SecureContainerView {
                            HStack {
                                Spacer()
                                Text(securityCode).monospaced()
                            }
                        }
                    },
                    actions: {[
                        UIAction(title: T.cardViewActionCopySecurityCode) { _ in
                            presenter.onCopySecurityCode()
                        }
                    ]}
                )
                .selected($selectedField, equals: .securityCode)
                .onChange(of: selectedField == .securityCode) { _, newValue in
                    if newValue {
                        presenter.onSelectSecurityCode()
                    }
                }
            }

            ItemDetailFormProtectionLevel(presenter.protectionLevel)
            ItemDetailFormTags(presenter.tags)
            ItemDetailFormNotes(presenter.notes)
        }
        .onAppear {
            selectedField = nil
        }
    }
}
