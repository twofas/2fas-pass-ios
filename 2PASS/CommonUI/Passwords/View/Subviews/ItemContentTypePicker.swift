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
        
    init(
        selectedFilter: Binding<ItemContentTypeFilter>,
        filters: [ItemContentTypeFilter]
    ) {
        self._selectedFilter = selectedFilter
        self.filters = filters
    }
    
    var body: some View {
        GeometryReader { geometry in
            let horizontalPadding: CGFloat = 16
            let spacing: CGFloat = 8
            let unselectedButtonWidth: CGFloat = 60 // Fixed width for unselected buttons
            let unselectedCount = filters.count - 1
            let totalSpacing = spacing * CGFloat(filters.count - 1) + (horizontalPadding * 2)
            let totalUnselectedWidth = unselectedButtonWidth * CGFloat(unselectedCount)
            let selectedButtonWidth = geometry.size.width - totalSpacing - totalUnselectedWidth
            
            HStack(spacing: spacing) {
                ForEach(filters, id: \.hashValue) { category in
                    let isSelected = selectedFilter.contentType == category.contentType
                    
                    ItemContentTypeFilterButton(
                        filter: category,
                        isSelected: isSelected,
                        width: isSelected ? selectedButtonWidth : unselectedButtonWidth
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedFilter = category
                        }
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
        }
    }
}

private struct ItemContentTypeFilterButton: View {
    let filter: ItemContentTypeFilter
    let isSelected: Bool
    let width: CGFloat
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
                }
            }
            .padding(.horizontal, isSelected ? 16 : 8)
            .padding(.vertical, 10)
            .frame(maxWidth: horizontalSizeClass == .regular ? .infinity : nil)
            .frame(width: horizontalSizeClass == .regular ? nil : width, height: 44)
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
