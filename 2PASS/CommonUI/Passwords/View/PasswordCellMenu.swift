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
        case .view: T.loginViewActionViewDetails
        case .edit: T.loginEdit
        case .copy(.loginUsername): T.loginViewActionCopyUsername
        case .copy(.loginPassword): T.loginViewActionCopyPassword
        case .copy(.secureNoteText): T.secureNoteViewActionCopy
        case .copy(.paymentCardNumber): T.cardViewActionCopyCardNumber
        case .copy(.paymentCardSecurityCode): T.cardViewActionCopySecurityCode
        case .goToURI: T.loginViewActionOpenUri
        case .moveToTrash: T.loginViewActionDelete
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
