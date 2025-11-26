// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public protocol ItemDataChangeRequest: Hashable {
    var contentType: ItemContentType { get }
    var allowChangeContentType: Bool { get }
    
    var name: String? { get }
    var protectionLevel: ItemProtectionLevel? { get }
    var tags: [ItemTagID]? { get }
}

public enum ItemChangeRequest: Hashable {
    case addLogin(LoginDataChangeRequest)
    case updateLogin(LoginItemData, LoginDataChangeRequest)
    case addSecureNote(SecureNoteDataChangeRequest)
    case updateSecureNote(SecureNoteItemData, SecureNoteDataChangeRequest)
    case addPaymentCard(PaymentCardDataChangeRequest)
    case updatePaymentCard(PaymentCardItemData, PaymentCardDataChangeRequest)

    public var isAdd: Bool {
        switch self {
        case .addLogin, .addSecureNote, .addPaymentCard: true
        case .updateLogin, .updateSecureNote, .updatePaymentCard: false
        }
    }

    public var isUpdate: Bool {
        switch self {
        case .addLogin, .addSecureNote, .addPaymentCard: false
        case .updateLogin, .updateSecureNote, .updatePaymentCard: true
        }
    }

    public var contentType: ItemContentType {
        switch self {
        case .addLogin, .updateLogin:
            return .login
        case .addSecureNote, .updateSecureNote:
            return .secureNote
        case .addPaymentCard, .updatePaymentCard:
            return .paymentCard
        }
    }
}
