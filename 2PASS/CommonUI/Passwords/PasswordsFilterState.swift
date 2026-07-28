// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common

/// Shared, mutable list UI state for the items list — the active filters, the search phrase, and the
/// multiselect (editing) state. A single instance is handed to both the iPad split (sidebar) and the
/// tab bar representations of the Passwords list, so switching between layouts preserves all of it.
/// Each `PasswordsPresenter` reads and writes here instead of in its own properties; representations
/// that should stay independent (e.g. the AutoFill list, SwiftUI previews) get their own private
/// instance via the default `init()`.
///
/// The type is `public` only so the app target can create one and thread it through CommonUI's flow
/// builders; the individual fields stay `internal` since they're an implementation detail of the
/// presenter.
public final class PasswordsFilterState {
    var selectedTag: ItemTagData?
    var selectedProtectionLevel: ItemProtectionLevel?
    var contentTypeFilter: ItemContentTypeFilter = .all
    var searchPhrase: String?

    /// Whether the list is in multiselect (editing) mode, and which items are selected. Restored into
    /// the other representation so a selection started in one layout continues in the other.
    var isSelecting: Bool = false
    var selectedItemIDs: Set<ItemID> = []

    public init() {}
}
