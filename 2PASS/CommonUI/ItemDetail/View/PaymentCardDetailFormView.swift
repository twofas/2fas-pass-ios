// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

private struct Constants {
    static let cardMaxWidth = 320.0
}

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
        CardView(
            issuer: presenter.paymentCardIssuer,
            name: presenter.name,
            cardNumberMask: presenter.cardNumberMask
        )
        .frame(maxWidth: Constants.cardMaxWidth)
        .padding(.horizontal, Spacing.xll3)
        .padding(.bottom, Spacing.s)
        
        ItemDetailSection {
            if let cardHolder = presenter.cardHolder {
                ItemDetailFormActionsRow(
                    key: .cardHolderLabel,
                    value: { Text(cardHolder) },
                    actions: {[
                        UIAction(title: String(localized: .cardViewActionCopyCardHolder)) { _ in
                            presenter.onCopyCardHolder()
                        }
                    ]}
                )
                .selected($selectedField, equals: .cardHolder)
                .onChange(of: selectedField == .cardHolder) { _, newValue in
                    if newValue {
                        presenter.onSelectCardHolder()
                    }
                }
            }
            
            if let cardNumber = presenter.cardNumber {
                ItemDetailFormActionsRow(
                    key: .cardNumberLabel,
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
                        UIAction(title: String(localized: .cardViewActionCopyCardNumber)) { _ in
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
                    key: .cardExpirationDateLabel,
                    value: { Text(expirationDate.formatted(.expirationDate)) },
                    actions: {[
                        UIAction(title: String(localized: .cardViewActionCopyExpirationDate)) { _ in
                            presenter.onCopyExpirationDate()
                        }
                    ]}
                )
                .selected($selectedField, equals: .expirationDate)
                .onChange(of: selectedField == .expirationDate) { _, newValue in
                    if newValue {
                        presenter.onSelectExpirationDate()
                    }
                }
            }
            
            if let securityCode = presenter.securityCode {
                ItemDetailFormActionsRow(
                    key: .cardSecurityCodeLabel,
                    value: {
                        SecureContainerView {
                            HStack {
                                Spacer()
                                Text(securityCode).monospaced()
                            }
                        }
                    },
                    actions: {[
                        UIAction(title: String(localized: .cardViewActionCopySecurityCode)) { _ in
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
            ItemDetailFormNotes(presenter.notes)
        }
        .onAppear {
            selectedField = nil
        }
    }
}
