// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

/// Where a Passwords list is embedded, which decides how it lays itself out. The composition layer
/// (the flow controllers) picks this per representation, so the view never has to inspect the device
/// or size class to decide its role.
public enum PasswordsListLayout {
    /// Self-contained list — the tab bar's Passwords tab (iPhone and iPad alike) and the AutoFill
    /// list. It hosts its own search bar, the inline content-type picker, and an inline
    /// selected-filter banner.
    case standalone

    /// The list column of the iPad split. Search lives in the detail column on iOS 26+, on the list
    /// column before that; the content-type picker and filters live in the sidebar, so the list only
    /// shows a top-anchored filter banner.
    case splitColumn
}

public extension PasswordsListLayout {
    /// From iOS 26 the split hosts the items search bar in the detail (secondary) column
    /// (`preferredSearchBarPlacement = .integrated`). Before iOS 26 that integrated placement isn't
    /// available, so the search bar stays on the list column even in the split. Single gate for the
    /// whole "who hosts the split's search bar" decision.
    static var splitHostsSearchInDetailColumn: Bool {
        if #available(iOS 26.0, *) { true } else { false }
    }
}
