// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public enum PasswordListOptions: Hashable {
    public enum TrashOptions {
        case yes
        case no
        case all // default
    }
    
    case filterByPhrase(String?, sortBy: SortType, trashed: TrashOptions)
    case findExistingByPasswordID(PasswordID)
    case findNotTrashedByPasswordID(PasswordID)
    case includePasswords([PasswordID])
    case allTrashed
    case allNotTrashed
    case all
}
