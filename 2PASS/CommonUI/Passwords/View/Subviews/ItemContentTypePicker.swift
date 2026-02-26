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
            filters: filters
        )
        .ignoresSafeArea()
        .onChange(of: selectedFilter) { oldValue, newValue in
            onChange(newValue)
        }
    }
}

struct ItemContentTypePicker: View {
    @Binding var selectedFilter: ItemContentTypeFilter
    let filters: [ItemContentTypeFilter]
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
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
        
    init(
        selectedFilter: Binding<ItemContentTypeFilter>,
        filters: [ItemContentTypeFilter]
    ) {
        self._selectedFilter = selectedFilter
        self.filters = filters
    }
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: spacing) {
                ForEach(filters, id: \.hashValue) { category in
                    let isSelected = selectedFilter.contentType == category.contentType
                    
                    ItemContentTypeFilterButton(
                        filter: category,
                        isSelected: isSelected,
                        width: buttonWidth(
                            isSelected: isSelected,
                            containerWidth: geometry.size.width
                        )
                    ) {
                        selectFilter(category)
                    }
                    .layoutPriority(isSelected ? 1 : 0)
                }
            }
            .frame(width: geometry.size.width - (horizontalPadding * 2), alignment: contentAlignment)
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
                    }
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
    
    private func buttonWidth(isSelected: Bool, containerWidth: CGFloat) -> CGFloat? {
        if UIDevice.isiPad {
            return equalButtonWidth(containerWidth: containerWidth)
        }
        
        if horizontalSizeClass == .regular {
            return nil
        }
        
        return isSelected ? nil : unselectedButtonWidth
    }
    
    private func equalButtonWidth(containerWidth: CGFloat) -> CGFloat? {
        guard filters.isEmpty == false else {
            return nil
        }
        
        let spacingWidth = spacing * CGFloat(max(filters.count - 1, 0))
        let availableWidth = containerWidth - (horizontalPadding * 2) - spacingWidth
        guard availableWidth > 0 else {
            return nil
        }
        return availableWidth / CGFloat(filters.count)
    }
}

private struct ItemContentTypeFilterButton: View {
    let filter: ItemContentTypeFilter
    let isSelected: Bool
    let width: CGFloat?
    let action: () -> Void
    
    @State private var pressing = false
    
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        Button(action: action) {
            let content = HStack(spacing: 6) {
                Image(systemName: filter.iconSystemName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : (colorScheme == .light ? .black.opacity(0.7) : .init(uiColor: UIColor(hexString: "#CBCBCB")!)))
                
                if isSelected || horizontalSizeClass == .regular {
                    Text(filter.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isSelected ? .white : (colorScheme == .light ? .black.opacity(0.7) : .init(uiColor: UIColor(hexString: "#CBCBCB")!)))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .fixedSize(horizontal: horizontalSizeClass == .compact && isSelected, vertical: false)
                }
            }
            .padding(.horizontal, isSelected ? 16 : 8)
            .padding(.vertical, 10)
            .frame(maxWidth: horizontalSizeClass == .regular && width == nil ? .infinity : nil)
            .frame(width: width, height: 44)
            .contentShape(Capsule())
            
            if #available(iOS 26.0, *) {
                content
                    .glassEffect(.regular.tint(isSelected ? Color(filter.color) : nil))
            } else {
                content
                    .background(
                        Capsule()
                            .fill(isSelected ? Color(filter.color) : colorScheme == .light ? .black.opacity(0.05) : .white.opacity(0.15))
                    )
            }
        }
        .buttonStyle(.plain)
    }
}
