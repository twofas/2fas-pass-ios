// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import Data

/// A top-level action shown in the sidebar footer (e.g. Connect, Settings). Kept generic so CommonUI
/// needn't know the app's sections — the app supplies these as data, mirroring the previous
/// `setFooterView(_:)` seam.
public struct SidebarFooterItem: Identifiable {
    public let id: String
    public let title: String
    public let systemImage: String
    /// Renders as a circular icon-only glass button instead of a labeled capsule. The title still
    /// feeds the button's accessibility label.
    public let isIconOnly: Bool
    public let action: () -> Void

    public init(id: String, title: String, systemImage: String, isIconOnly: Bool = false, action: @escaping () -> Void) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.isIconOnly = isIconOnly
        self.action = action
    }
}

/// Observable snapshot the SwiftUI sidebar binds to. Refreshed from `PasswordsPresenter` whenever the
/// list reloads (via `AppSidebarViewController.reloadFilters()`), turning the old imperative
/// collection-view rebuild into a reactive update. Actions are forwarded straight to the presenter,
/// whose `reload()` cycles back through `refresh()` — so the model never owns filter state, it mirrors
/// the presenter's.
@MainActor
@Observable
final class AppSidebarModel {

    struct ProtectionRow: Identifiable {
        let level: ItemProtectionLevel
        let count: Int
        var id: ItemProtectionLevel { level }
    }

    struct TagRow: Identifiable {
        let tag: ItemTagData
        let count: Int
        var id: ItemTagID { tag.tagID }
    }

    let filters: [ItemContentTypeFilter] = ItemContentTypeFilter.allKnown

    private(set) var contentTypeFilter: ItemContentTypeFilter = .all
    private(set) var protectionRows: [ProtectionRow] = ItemProtectionLevel.allCases.map {
        ProtectionRow(level: $0, count: 0)
    }
    private(set) var tagRows: [TagRow] = []
    private(set) var selectedProtectionLevel: ItemProtectionLevel?
    private(set) var selectedTag: ItemTagData?

    var footerItems: [SidebarFooterItem] = []
    var badgedFooterItemIDs: Set<String> = []

    weak var presenter: PasswordsPresenter?

    /// True when a protection level or tag filter is active. The content-type picker is a persistent
    /// selector (it always has a value, defaulting to All), so it is deliberately excluded from the
    /// "Filter" / Clear concept — matching the iPhone list and the previous UIKit sidebar.
    var hasActiveFilter: Bool {
        selectedProtectionLevel != nil || selectedTag != nil
    }

    /// Re-reads the rendered snapshot from the presenter: the selection mirror plus `listAllTags()`
    /// and the per-level / per-tag counts, all counts from a single storage pass.
    func refresh() {
        guard let presenter else { return }
        refreshSelection()
        let counts = presenter.itemFilterCounts()
        protectionRows = ItemProtectionLevel.allCases.map {
            ProtectionRow(level: $0, count: counts.byProtectionLevel[$0] ?? 0)
        }
        tagRows = presenter.listAllTags().map {
            TagRow(tag: $0, count: counts.byTag[$0.tagID] ?? 0)
        }
    }

    /// Mirrors just the selected filters — the cheap part of `refresh()`, used alone for reloads
    /// triggered by a filter change, where the counts cannot have moved but the toggled selection
    /// must round-trip back into the model.
    func refreshSelection() {
        guard let presenter else { return }
        contentTypeFilter = presenter.contentTypeFilter
        selectedProtectionLevel = presenter.selectedFilterProtectionLevel
        selectedTag = presenter.selectedFilterTag
    }

    // MARK: - Actions

    func setContentTypeFilter(_ filter: ItemContentTypeFilter) {
        guard filter != contentTypeFilter else { return }
        // Reflect the new value immediately so the bound picker doesn't snap back before `reload()`
        // cycles through `refresh()`.
        contentTypeFilter = filter
        presenter?.onSetContentTypeFilter(filter)
    }

    func toggleProtectionLevel(_ level: ItemProtectionLevel) {
        let active = selectedProtectionLevel == level
        presenter?.onSelectFilterProtectionLevel(active ? nil : level)
    }

    func toggleTag(_ tag: ItemTagData) {
        let active = selectedTag?.tagID == tag.tagID
        presenter?.onSelectFilterTag(active ? nil : tag)
    }

    /// Resets the protection level and tag filters. The content-type picker is left untouched — it is
    /// a persistent selector, not part of the "Filter" / Clear concept.
    func clearFilters() {
        presenter?.onSelectFilterProtectionLevel(nil)
        presenter?.onSelectFilterTag(nil)
    }
}

#if DEBUG
extension AppSidebarModel {

    /// Sample model for SwiftUI previews. Seeds the snapshot directly since it normally comes from
    /// `PasswordsPresenter` — possible here because `private(set)` setters are visible in this file.
    static func preview() -> AppSidebarModel {
        let model = AppSidebarModel()
        model.protectionRows = zip(ItemProtectionLevel.allCases, [31, 12, 4]).map {
            ProtectionRow(level: $0, count: $1)
        }
        model.tagRows = [
            TagRow(
                tag: ItemTagData(tagID: UUID(), vaultID: UUID(), name: "Work", color: .indigo, position: 0, modificationDate: Date()),
                count: 8
            ),
            TagRow(
                tag: ItemTagData(tagID: UUID(), vaultID: UUID(), name: "Personal", color: .green, position: 1, modificationDate: Date()),
                count: 5
            )
        ]
        model.selectedProtectionLevel = ItemProtectionLevel.allCases.dropFirst().first
        model.footerItems = [
            SidebarFooterItem(id: "connect", title: "Connect", systemImage: "personalhotspot", action: {}),
            SidebarFooterItem(id: "settings", title: "Settings", systemImage: "gear", isIconOnly: true, action: {})
        ]
        model.badgedFooterItemIDs = ["settings"]
        return model
    }
}
#endif
