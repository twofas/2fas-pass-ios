// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI
import Common

struct BulkProtectionLevelSelectionView: View {
    
    @Bindable
    var presenter: BulkProtectionLevelPresenter
    
    var body: some View {
        List {
            ForEach(ItemProtectionLevel.allCases, id: \.self) { level in
                BulkProtectionLevelRow(
                    level: level,
                    count: presenter.count(for: level),
                    state: presenter.indicatorState(for: level),
                    onSelect: { presenter.selectProtectionLevel(level) }
                )
            }
        }
        .listStyle(.insetGrouped)
        .scrollBounceBehavior(.basedOnSize)
    }
}

private struct BulkProtectionLevelRow: View {
    let level: ItemProtectionLevel
    let count: Int
    let state: SelectionIndicatorState
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.m) {
                level.icon
                    .renderingMode(.template)
                    .foregroundStyle(.accent)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 0) {
                    Text(level.title)
                        .font(.subheadlineEmphasized)
                        .foregroundStyle(.primary)
                    
                    if count > 0 {
                        Text(.commonItemsCount(Int32(count)))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                SelectionIndicatorIcon(state)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let flowController = BulkProtectionLevelPreviewFlowController()
    let presenter = BulkProtectionLevelPresenter(
        flowController: flowController,
        selectedItems: []
    )
    BulkProtectionLevelSelectionView(presenter: presenter)
}

private final class BulkProtectionLevelPreviewFlowController: BulkProtectionLevelFlowControlling {
    func handleCancel() {}
    func handleConfirmChange(_ level: ItemProtectionLevel) {}
    @MainActor
    func toConfirmChangeAlert(selectedCount: Int, source: UIBarButtonItem) async -> Bool { false }
}
