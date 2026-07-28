// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

/// Primary column of the iPad unified split, in SwiftUI. Content-type filters use the same pill picker
/// as the iPhone items list (top); the "Filter" title with Clear, protection levels and tags follow as
/// a sidebar list. Top-level sections (Connect, Settings) live in a footer supplied by the split
/// coordinator. All state is read from / written back to `AppSidebarModel`, which mirrors
/// `PasswordsPresenter`.
struct AppSidebarView: View {

    let model: AppSidebarModel

    /// Reserved leading column so the tier icons and the smaller tag dots align their titles — the
    /// SwiftUI equivalent of the old `imageProperties.reservedLayoutSize`.
    private let iconColumnWidth = Spacing.xll2

    var body: some View {
        List {
            contentTypeSection
            protectionSection
            tagSection
        }
        .listSectionSpacing(Spacing.s)
        .scrollBounceBehavior(.basedOnSize)
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            footer
        }
        .ignoresSafeArea(.keyboard)
    }

    // MARK: - Content types + Filter header

    private var contentTypeSection: some View {
        Section {
            ItemContentTypePicker(selectedFilter: contentTypeBinding, filters: model.filters, axis: .vertical)
                .listRowInsets(EdgeInsets(top: Spacing.s, leading: 0, bottom: Spacing.s, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
        }
    }

    /// The "Filter" title with the trailing Clear button, rendered below the pills as the content-types
    /// section footer so it reads as a section title above "Security Tier" / "Tags".
    private var filterHeader: some View {
        HStack {
            Text(.homeListMenuFilter)
                .font(.title3.bold())
                .foregroundStyle(.secondary)

            Spacer()

            if model.hasActiveFilter {
                Button(.commonClear) {
                    model.clearFilters()
                }
                .font(.headline)
                .foregroundStyle(.accent)
            }
        }
        .textCase(nil)
        .padding(.vertical, Spacing.l)
    }

    private var contentTypeBinding: Binding<ItemContentTypeFilter> {
        Binding(
            get: { model.contentTypeFilter },
            set: { model.setContentTypeFilter($0) }
        )
    }

    // MARK: - Protection levels

    private var protectionSection: some View {
        Section {
            ForEach(model.protectionRows) { row in
                filterRow(
                    isSelected: model.selectedProtectionLevel == row.level,
                    action: { model.toggleProtectionLevel(row.level) }
                ) {
                    row.level.icon
                        .renderingMode(.template)
                        .foregroundStyle(.accent)
                        .frame(width: iconColumnWidth)
                        .accessibilityHidden(true)

                    Text("\(row.level.title) (\(row.count))")
                }
            }
        } header: {
            VStack(alignment: .leading, spacing: Spacing.m) {
                filterHeader
                Text(.settingsEntryProtectionLevel).textCase(nil)
            }
            .padding(.trailing, -Spacing.s)
        }
    }

    // MARK: - Tags

    @ViewBuilder
    private var tagSection: some View {
        if model.tagRows.isEmpty == false {
            Section {
                ForEach(model.tagRows) { row in
                    filterRow(
                        isSelected: model.selectedTag?.tagID == row.tag.tagID,
                        action: { model.toggleTag(row.tag) }
                    ) {
                        Circle()
                            .fill(Color(UIColor(row.tag.color)))
                            .frame(width: ItemTagColorMetrics.small.size, height: ItemTagColorMetrics.small.size)
                            .frame(width: iconColumnWidth)

                        Text("\(row.tag.name) (\(row.count))")
                    }
                }
            } header: {
                Text(.loginTags).textCase(nil)
            }
        }
    }

    /// A tappable filter row: leading content (icon/dot + title), a trailing checkmark only when active.
    /// An active filter is marked by its checkmark alone — no persistent selected-state background,
    /// matching the previous UIKit sidebar.
    private func filterRow<Content: View>(
        isSelected: Bool,
        action: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Spacing.s) {
                content()
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)

                // The active state is exposed through the `.isSelected` trait below; the checkmark
                // is its visual-only counterpart.
                Image(systemName: "checkmark")
                    .foregroundStyle(.accent)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Footer (Connect / Settings)

    private var footer: some View {
        HStack(spacing: Spacing.l) {
            ForEach(model.footerItems) { item in
                footerButton(item)
            }
        }
        .padding(.horizontal, Spacing.l)
        .padding(.vertical, Spacing.m)
    }

    private func footerButton(_ item: SidebarFooterItem) -> some View {
        let isBadged = model.badgedFooterItemIDs.contains(item.id)
        return Button(action: item.action) {
            footerLabel(item)
        }
        .buttonStyle(.plain)
        // The explicit label covers the icon-only variant (whose image would otherwise be read by
        // its symbol name), and the badge dot is conveyed as the button's value instead of the
        // decorative circle.
        .accessibilityLabel(item.title)
        .accessibilityValue(isBadged ? String(localized: .commonError) : "")
        .overlay(alignment: .topTrailing) {
            if isBadged {
                Circle()
                    .fill(Color.danger500)
                    .frame(width: 10, height: 10)
                    .padding(Spacing.xs)
                    .offset(x: 3, y: -3)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private func footerLabel(_ item: SidebarFooterItem) -> some View {
        if item.isIconOnly {
            iconOnlyFooterLabel(item)
        } else {
            labeledFooterLabel(item)
        }
    }

    /// Icon-only footer item (Settings), rendered as a circular glass button.
    @ViewBuilder
    private func iconOnlyFooterLabel(_ item: SidebarFooterItem) -> some View {
        let content = Image(systemName: item.systemImage)
            .font(.system(size: 17, weight: .regular))
            .foregroundStyle(.primary)
            .frame(width: 44, height: 44)
            .contentShape(Circle())

        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .circle)
        } else {
            content.background(Color.neutral100, in: Circle())
        }
    }

    /// Footer item with its icon and title side by side, filling the available width.
    @ViewBuilder
    private func labeledFooterLabel(_ item: SidebarFooterItem) -> some View {
        let content = HStack(spacing: Spacing.s) {
            Image(systemName: item.systemImage)
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(.primary)
            Text(item.title)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .padding(.horizontal, Spacing.l)
        .contentShape(Capsule())

        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content.background(Color.neutral100, in: Capsule())
        }
    }
}

#if DEBUG
#Preview {
    AppSidebarView(model: .preview())
}
#endif
