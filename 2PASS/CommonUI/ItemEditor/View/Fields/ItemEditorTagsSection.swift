// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct ItemEditorTagsSection: View {
    
    let presenter: ItemEditorFormPresenter
    let resignFirstResponder: Callback

    var body: some View {
        Section {
            Button {
                resignFirstResponder()
                presenter.onSelectTags()
            } label: {
                HStack {
                    Text(.loginSelectedTags)
                        .foregroundStyle(Asset.mainTextColor.swiftUIColor)
                    
                    Spacer()
                    
                    if !presenter.selectedTags.isEmpty {
                        TagsDisplayView(tags: presenter.selectedTags)
                            .foregroundStyle(.neutral500)
                    } else {
                        Text("(0)")
                            .foregroundStyle(.neutral500)
                    }
                    
                    Image(systemName: "chevron.forward")
                        .foregroundStyle(.neutral500)
                }
                .contentShape(Rectangle())
            }
            .formFieldChanged(presenter.tagsChanged)
            .buttonStyle(.plain)
        } header: {
            Text(.loginTagsHeader)
        } footer: {
            Text(.loginTagsDescription)
        }
        .listSectionSpacing(Spacing.l)
    }
}

private struct TagsDisplayView: View {
    let tags: [ItemTagData]
    @State private var visibleTagsCount: Int = 0
    @State private var availableWidth: CGFloat = 0
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(Array(tags.prefix(visibleTagsCount).enumerated()), id: \.element.tagID) { index, tag in
                    Text(tag.name)
                        .lineLimit(1)
                    
                    if index < visibleTagsCount - 1 {
                        Text(", ")
                    }
                }
                
                if visibleTagsCount < tags.count {
                    Text("(+\(tags.count - visibleTagsCount))")
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            availableWidth = geometry.size.width
                            calculateVisibleTags(width: availableWidth)
                        }
                        .onChange(of: tags) { _, _ in
                            calculateVisibleTags(width: availableWidth)
                        }
                }
            )
        }
        .frame(height: 20)
    }
    
    private func calculateVisibleTags(width: CGFloat) {
        guard width > 0 else { return }
        
        var totalWidth: CGFloat = 0
        var count = 0
        let font = UIFont.preferredFont(forTextStyle: .body)
        
        // Reserve space for counter if needed
        let counterSpace: CGFloat = tags.count > 1 ? 40 : 0
        let availableSpace = width - counterSpace
        
        for (index, tag) in tags.enumerated() {
            let tagText = tag.name + (index < tags.count - 1 ? ", " : "")
            let textWidth = tagText.size(withAttributes: [.font: font]).width
            
            if totalWidth + textWidth <= availableSpace {
                totalWidth += textWidth
                count += 1
            } else {
                break
            }
        }
        
        // Ensure at least the counter is shown if no tags fit
        if count == 0 && !tags.isEmpty {
            visibleTagsCount = 0
        } else {
            visibleTagsCount = count
        }
    }
}
