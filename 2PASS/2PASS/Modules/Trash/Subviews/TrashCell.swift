// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct TrashCell: View {
    
    let data: TrashItemData
    let presenter: TrashPresenter
    
    var body: some View {
        HStack(alignment: .center, spacing: Spacing.l) {
            IconRendererView(content: presenter.icons[data.itemID])
                .controlSize(.small)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(data.name, format: .itemName)
                    .font(.bodyEmphasized)
                    .foregroundStyle(.neutral950)
                    .lineLimit(1)
                
                if let description = data.description {
                    Text(description)
                        .font(.footnote)
                        .foregroundStyle(.neutral500)
                        .lineLimit(1)
                }
                
                Text(T.trashDeletedAt(data.deletedDate.formatted(date: .numeric, time: .standard)).localizedKey)
                    .lineLimit(1)
                    .font(.footnote)
                    .foregroundStyle(.neutral500)
            }
            
            Spacer()
            
            Menu {
                Button {
                    presenter.onRestore(itemID: data.itemID)
                } label: {
                    HStack {
                        Image(systemName: "arrow.2.squarepath")
                        Text(T.trashRestore.localizedKey)
                    }
                }
                
                Button(role: ButtonRole.destructive) {
                    presenter.onDelete(itemID: data.itemID)
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text(T.trashRemovePermanently.localizedKey)
                    }
                }
            } label: {
                Group {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Asset.labelSecondaryColor.swiftUIColor)
                }
                .frame(width: 40, height: 40, alignment: .trailing)
            }
            .tint(nil)
        }
    }
}
