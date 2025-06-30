// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

enum PasswordCellMenu: CaseIterable {
    case view
    case edit
    case copyUsername
    case copyPassword
    case goToURI
    case moveToTrash
    
    var label: String {
        switch self {
        case .view: T.loginViewActionViewDetails
        case .edit: T.commonEdit
        case .copyUsername: T.loginViewActionCopyUsername
        case .copyPassword: T.loginViewActionCopyPassword
        case .goToURI: T.loginViewActionOpenUri
        case .moveToTrash: T.loginViewActionDelete
        }
    }
    
    var icon: UIImage? {
        switch self {
        case .view: UIImage(systemName: "wallet.pass")
        case .edit: UIImage(systemName: "square.and.pencil")
        case .copyUsername: UIImage(systemName: "person")
        case .copyPassword: UIImage(systemName: "ellipsis.rectangle")
        case .goToURI: UIImage(systemName: "safari")
        case .moveToTrash: UIImage(systemName: "trash")
        }
    }
    
    var attributes: UIMenuElement.Attributes {
        guard self == .moveToTrash else {
            return []
        }
        return [.destructive]
    }
}
