// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct CategoryPickerUIKitWrapper: View {
    
    let categories: [CategoryItem]
    let onChange: (CategoryItem) -> Void
    
    @State private var selectedCategory: CategoryItem
    
    public init(
        initialCategory: CategoryItem,
        categories: [CategoryItem],
        onChange: @escaping (CategoryItem) -> Void
    ) {
        self.selectedCategory = initialCategory
        self.categories = categories
        self.onChange = onChange
    }
    
    var body: some View {
        CategoryPicker(
            selectedCategory: $selectedCategory,
            categories: categories
        )
        .onChange(of: selectedCategory) { oldValue, newValue in
            onChange(newValue)
        }
    }
}

struct CategoryItem: Hashable {
    
    public let contentType: ItemContentTypeFilter
    public let title: String
    public let icon: String
    public let color: Color
    
    public init(contentType: ItemContentTypeFilter, title: String, icon: String, color: Color) {
        self.contentType = contentType
        self.title = title
        self.icon = icon
        self.color = color
    }
}

struct CategoryPicker: View {
    @Binding var selectedCategory: CategoryItem
    let categories: [CategoryItem]
        
    init(
        selectedCategory: Binding<CategoryItem>,
        categories: [CategoryItem]
    ) {
        self._selectedCategory = selectedCategory
        self.categories = categories
    }
    
    var body: some View {
        GeometryReader { geometry in
            let horizontalPadding: CGFloat = 16
            let spacing: CGFloat = 8
            let unselectedButtonWidth: CGFloat = 60 // Fixed width for unselected buttons
            let unselectedCount = categories.count - 1
            let totalSpacing = spacing * CGFloat(categories.count - 1) + (horizontalPadding * 2)
            let totalUnselectedWidth = unselectedButtonWidth * CGFloat(unselectedCount)
            let selectedButtonWidth = geometry.size.width - totalSpacing - totalUnselectedWidth
            
            HStack(spacing: spacing) {
                ForEach(categories, id: \.contentType) { category in
                    let isSelected = selectedCategory.contentType == category.contentType
                    
                    CategoryButton(
                        category: category,
                        isSelected: isSelected,
                        width: isSelected ? selectedButtonWidth : unselectedButtonWidth
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
        }
    }
}

struct CategoryButton: View {
    let category: CategoryItem
    let isSelected: Bool
    let width: CGFloat
    let action: () -> Void
    
    @State private var pressing = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(isSelected ? .white : .neutral500)
                
                if isSelected {
                    Text(category.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(.horizontal, isSelected ? 16 : 8)
            .padding(.vertical, 10)
            .frame(width: width, height: 40)
            .background(
                Capsule()
                    .fill(isSelected ? category.color : .neutral100)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
