// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

enum PasswordCellMenu: Hashable {
    
    enum Field {
        case loginUsername
        case loginPassword
        case secureNoteText
        case paymentCardNumber
        case paymentCardSecurityCode
    }
    
    case view
    case edit
    case copy(Field)
    case goToURI(uris: [String])
    case moveToTrash
    
    var label: String {
        switch self {
        case .view: String(localized: .loginViewActionViewDetails)
        case .edit: String(localized: .loginEdit)
        case .copy(.loginUsername): String(localized: .loginViewActionCopyUsername)
        case .copy(.loginPassword): String(localized: .loginViewActionCopyPassword)
        case .copy(.secureNoteText): String(localized: .secureNoteViewActionCopy)
        case .copy(.paymentCardNumber): String(localized: .cardViewActionCopyCardNumber)
        case .copy(.paymentCardSecurityCode): String(localized: .cardViewActionCopySecurityCode)
        case .goToURI: String(localized: .loginViewActionOpenUri)
        case .moveToTrash: String(localized: .loginViewActionDelete)
        }
    }
    
    var icon: UIImage? {
        switch self {
        case .view: UIImage(systemName: "wallet.pass")
        case .edit: UIImage(systemName: "square.and.pencil")
        case .copy(.loginUsername): UIImage(systemName: "person")
        case .copy(.loginPassword): UIImage(systemName: "ellipsis.rectangle")
        case .copy(.secureNoteText): UIImage(systemName: "document.on.document")
        case .copy(.paymentCardNumber): UIImage(systemName: "creditcard")
        case .copy(.paymentCardSecurityCode): UIImage(systemName: "creditcard.and.123")
        case .goToURI: UIImage(systemName: "arrow.up.right")
        case .moveToTrash: UIImage(systemName: "trash")
        }
    }
    
    var attributes: UIMenuElement.Attributes {
        guard case .moveToTrash = self else {
            return []
        }
        return [.destructive]
    }
}
