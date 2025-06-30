// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common

private struct Constants {
    static let itemBorderCornerRadius = 12.0
    static let titleIconSize = 24.0
}

struct ConnectPullReqestItem {
    let name: String
    let username: String?
    let iconContent: IconContent?
}

struct ConnectPullReqestContentView<Icon, Actions>: View where Icon: View, Actions: View {
    
    let icon: Icon
    let title: Text
    let description: Text
    let item: ConnectPullReqestItem?
    let actions: Actions
    
    init(title: Text, description: Text, item: ConnectPullReqestItem? = nil, @ViewBuilder icon: () -> Icon, @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.icon = icon()
        self.description = description
        self.item = item
        self.actions = actions()
    }
    
    var body: some View {
        VStack(spacing: Spacing.xl) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                Label {
                    title
                        .font(.title2Emphasized)
                } icon: {
                    icon
                        .font(.system(size: Constants.titleIconSize))
                }
                
                description
                    .font(.subheadline)
                    .foregroundStyle(.neutral600)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            if let item {
                itemView(for: item)
            }
            
            HStack(spacing: Spacing.l) {
                actions
            }
            .padding(.top, Spacing.s)
            .controlSize(.large)
        }
    }
    
    @ViewBuilder
    private func itemView(for item: ConnectPullReqestItem) -> some View {
        HStack(spacing: Spacing.m) {
            IconRendererView(content: item.iconContent)
                .controlSize(.small)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(item.name, format: .itemName)
                    .font(.bodyEmphasized)
                    .foregroundStyle(.neutral950)
                
                if let username = item.username {
                    Text(username)
                        .font(.footnote)
                        .foregroundStyle(.neutral500)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(Spacing.l)
        .background {
            RoundedRectangle(cornerRadius: Constants.itemBorderCornerRadius)
                .stroke(Color.neutral100)
        }
    }
}

#Preview {
    let item = ConnectPullReqestItem(name: "Name", username: "Username", iconContent: .label("NA", color: nil))
    
    ConnectPullReqestContentView(
        title: Text("Title"),
        description: Text("Description"),
        item: item,
        icon: {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.brand500)
        },
        actions: {
            Button("Cancel") {
            }
            .buttonStyle(.bezeledGray)
            
            Button("Send") {
            }
            .buttonStyle(.bezeled)
        }
    )
    .padding()
}
