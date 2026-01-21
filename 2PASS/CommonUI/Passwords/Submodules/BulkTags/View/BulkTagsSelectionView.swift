// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct BulkTagsSelectionView: View {

    @Bindable
    var presenter: BulkTagsPresenter

    var body: some View {
        List {
            ForEach(presenter.tagItems) { item in
                BulkTagRow(
                    tag: item.tag,
                    count: item.itemsWithTagCount,
                    state: item.state,
                    onSelect: { presenter.toggleTag(item.tag) }
                )
            }

            Button {
                presenter.onAddNewTag()
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "plus")

                    Text(.tagsAddNewCta)
                        .font(.body)

                    Spacer()
                }
                .contentShape(Rectangle())
            }
        }
        .overlay {
            if presenter.tagItems.isEmpty {
                EmptyListView(Text(.tagsEmptyList))
            }
        }
        .listStyle(.insetGrouped)
        .scrollBounceBehavior(.basedOnSize)
        .router(router: BulkTagsRouter(), destination: $presenter.destination)
    }
}

private struct BulkTagRow: View {
    let tag: ItemTagData
    let count: Int
    let state: SelectionIndicatorState
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                TagContentCell(
                    name: Text(tag.name),
                    color: tag.color,
                    subtitle: count > 0 ? Text(.commonItemsCount(Int32(count))) : nil
                )

                Spacer()

                SelectionIndicatorIcon(state)
                    .unselectedStyle(.circle)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private let previewContent = List {
    Section("Selection States" as String) {
        BulkTagRow(
            tag: ItemTagData(
                tagID: ItemTagID(),
                vaultID: VaultID(),
                name: "All items have this" as String,
                color: .green,
                position: 0,
                modificationDate: Date()
            ),
            count: 5,
            state: .selected,
            onSelect: {}
        )

        BulkTagRow(
            tag: ItemTagData(
                tagID: ItemTagID(),
                vaultID: VaultID(),
                name: "Some items have this" as String,
                color: .orange,
                position: 1,
                modificationDate: Date()
            ),
            count: 3,
            state: .mixed,
            onSelect: {}
        )

        BulkTagRow(
            tag: ItemTagData(
                tagID: ItemTagID(),
                vaultID: VaultID(),
                name: "No items have this" as String,
                color: .purple,
                position: 2,
                modificationDate: Date()
            ),
            count: 0,
            state: .unselected,
            onSelect: {}
        )
    }
}

#Preview("BulkTagRow States") {
    previewContent
}

#Preview("BulkTagRow States - Sheet") {
    Color.black
        .sheet(isPresented: .constant(true)) {
            previewContent
        }
}
