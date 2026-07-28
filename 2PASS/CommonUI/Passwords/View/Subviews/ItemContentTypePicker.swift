// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct ItemContentTypePickerUIKitWrapper: View {

    let filters: [ItemContentTypeFilter]
    let onChange: (ItemContentTypeFilter) -> Void

    @State private var selectedFilter: ItemContentTypeFilter

    public init(
        initialFilter: ItemContentTypeFilter,
        filters: [ItemContentTypeFilter],
        onChange: @escaping (ItemContentTypeFilter) -> Void
    ) {
        self.selectedFilter = initialFilter
        self.filters = filters
        self.onChange = onChange
    }

    var body: some View {
        ItemContentTypePicker(
            selectedFilter: $selectedFilter,
            filters: filters,
            axis: .horizontal
        )
        .ignoresSafeArea()
        .onChange(of: selectedFilter) { oldValue, newValue in
            onChange(newValue)
        }
    }
}

struct ItemContentTypePicker: View {

    /// Orientation of the picker. The split's sidebar renders it `.vertical`; the standalone list's
    /// inline picker renders it `.horizontal` regardless of the list's width.
    enum Axis {
        case horizontal
        case vertical
    }

    @Binding var selectedFilter: ItemContentTypeFilter
    let filters: [ItemContentTypeFilter]
    let axis: Axis

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // Natural width of the pill row, measured from the compact layout. Drives whether the row is
    // pulled to the trailing edge (see `horizontalAlignment(fittingWidth:)`).
    @State private var contentWidth: CGFloat = 0

    private let horizontalPadding: CGFloat = 16
    private let spacing: CGFloat = 8
    private let unselectedButtonWidth: CGFloat = 60
    private let swipeThreshold: CGFloat = 40

    private var contentAlignment: Alignment {
        guard filters.count >= 2 else {
            return .leading
        }

        let trailingAlignedFilters = filters.suffix(2)
        return trailingAlignedFilters.contains(selectedFilter) ? .trailing : .leading
    }

    // Pull the row to the trailing edge only when the pills overflow the available width; when
    // everything fits, keep them leading so selecting a filter doesn't jump the whole row sideways.
    private func horizontalAlignment(fittingWidth availableWidth: CGFloat) -> Alignment {
        guard contentWidth > availableWidth else {
            return .leading
        }
        return contentAlignment
    }

    init(
        selectedFilter: Binding<ItemContentTypeFilter>,
        filters: [ItemContentTypeFilter],
        axis: Axis
    ) {
        self._selectedFilter = selectedFilter
        self.filters = filters
        self.axis = axis
    }

    var body: some View {
        switch axis {
        case .vertical:
            verticalBody
        case .horizontal:
            horizontalBody
        }
    }

    // iPad sidebar: a vertical stack of full-width, always-labeled pills. No horizontal padding here —
    // the host cell's content margins position the stack so the pills align with the filter rows.
    private var verticalBody: some View {
        VStack(spacing: spacing) {
            ForEach(filters, id: \.hashValue) { category in
                ItemContentTypeFilterButton(
                    filter: category,
                    isSelected: selectedFilter.contentType == category.contentType,
                    width: nil,
                    style: .expanded
                ) {
                    selectFilter(category)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // A horizontal row of pills. In a regular width every pill shows its icon + title at equal width,
    // together filling the row. In a compact width pills size to content, show their title only when
    // selected, stay leading while they fit, and shift to the trailing edge only when they overflow
    // the available width (with swipe-to-jump).
    private var horizontalBody: some View {
        GeometryReader { geometry in
            let isRegularWidth = horizontalSizeClass == .regular
            let availableWidth = geometry.size.width - (horizontalPadding * 2)
            HStack(spacing: spacing) {
                ForEach(filters, id: \.hashValue) { category in
                    let isSelected = selectedFilter.contentType == category.contentType

                    ItemContentTypeFilterButton(
                        filter: category,
                        isSelected: isSelected,
                        width: isRegularWidth ? nil : buttonWidth(isSelected: isSelected),
                        style: isRegularWidth ? .equalWidth : .compactPill
                    ) {
                        selectFilter(category)
                    }
                    .layoutPriority(isRegularWidth ? 0 : (isSelected ? 1 : 0))
                }
            }
            // Measure the pills' natural width (before the fixed-width frame below constrains it) so
            // the trailing alignment only kicks in when they actually overflow the available width.
            .observeWidth { contentWidth = $0 }
            .frame(
                width: availableWidth,
                alignment: isRegularWidth ? .center : horizontalAlignment(fittingWidth: availableWidth)
            )
            .padding(.horizontal, horizontalPadding)
            .contentShape(Rectangle())
            .highPriorityGesture(
                DragGesture(minimumDistance: swipeThreshold)
                    .onEnded { value in
                        if value.translation.width >= swipeThreshold {
                            if let firstFilter = filters.first {
                                selectFilter(firstFilter)
                            }
                        } else if value.translation.width <= -swipeThreshold {
                            if let lastFilter = filters.last {
                                selectFilter(lastFilter)
                            }
                        }
                    },
                including: isRegularWidth ? .subviews : .all
            )
        }
    }

    private func selectFilter(_ filter: ItemContentTypeFilter) {
        guard selectedFilter != filter else {
            return
        }
        
        let animation = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.8)
        if UIAccessibility.isReduceMotionEnabled {
            selectedFilter = filter
        } else {
            withAnimation(animation) {
                selectedFilter = filter
            }
        }
    }
    
    private func buttonWidth(isSelected: Bool) -> CGFloat? {
        isSelected ? nil : unselectedButtonWidth
    }
}

private struct ItemContentTypeFilterButton: View {

    enum Style {
        /// Compact horizontal pill (iPhone): title only when selected, sizes to its content, glass fill.
        case compactPill
        /// Regular horizontal pill (iPad standalone list): always icon + title, equal width, glass fill.
        case equalWidth
        /// Vertical sidebar pill (iPad split): always icon + title, full width, leading, plain fill.
        case expanded
    }

    let filter: ItemContentTypeFilter
    let isSelected: Bool
    let width: CGFloat?
    var style: Style = .compactPill
    let action: () -> Void

    @State private var pressing = false

    @Environment(\.colorScheme) private var colorScheme

    private var showsTitle: Bool {
        style != .compactPill || isSelected
    }

    private var fillsWidth: Bool {
        style == .equalWidth || style == .expanded
    }

    private var usesPlainFill: Bool {
        style == .expanded
    }

    var body: some View {
        Button(action: action) {
            backgroundedContent
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var backgroundedContent: some View {
        let content = HStack(spacing: 6) {
            Image(systemName: filter.iconSystemName)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(foregroundColor)

            if showsTitle {
                Text(filter.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(foregroundColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: style == .compactPill && isSelected, vertical: false)
            }

            if style == .expanded {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, showsTitle ? 16 : 8)
        .padding(.vertical, 10)
        .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: style == .expanded ? .leading : .center)
        .frame(width: fillsWidth ? nil : width, height: 44)
        .contentShape(Capsule())

        // The iPad sidebar pills use a plain fill — no glass; the horizontal pickers keep glass.
        if #available(iOS 26.0, *), usesPlainFill == false {
            content
                .glassEffect(.regular.tint(isSelected ? Color(filter.color) : nil))
        } else {
            content
                .background(Capsule().fill(fillColor))
        }
    }

    private var fillColor: Color {
        if isSelected {
            return Color(filter.color)
        }
        return colorScheme == .light ? .black.opacity(0.05) : .white.opacity(0.15)
    }

    private var foregroundColor: Color {
        if isSelected {
            return .white
        }
        return colorScheme == .light ? .black.opacity(0.7) : .init(uiColor: UIColor(hexString: "#CBCBCB")!)
    }
}
