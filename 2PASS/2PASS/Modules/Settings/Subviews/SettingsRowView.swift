// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

enum SettingsRowActionIcon: String {
    case chevron = "chevron.right"
    case link = "arrow.up.right"
    case share = "square.and.arrow.up"
    
    var color: Color {
        switch self {
        case .link, .share: Asset.accentColor.swiftUIColor
        default: Asset.inactiveColor.swiftUIColor
        }
    }
}

struct SettingsRowView<AdditionalInfo>: View where AdditionalInfo: View {
    let icon: SettingsIcon?
    let title: Text
    let actionIcon: SettingsRowActionIcon?
    let showBadge: Bool
    let additionalInfo: AdditionalInfo?
    
    private var isButtonStyle = false
    
    @Environment(\.isEnabled)
    private var isEnabled
    
    init(
        icon: SettingsIcon? = nil,
        title: Text,
        actionIcon: SettingsRowActionIcon? = .chevron,
        showBadge: Bool = false,
        @ViewBuilder additionalInfo: () -> AdditionalInfo
    ) {
        self.icon = icon
        self.title = title
        self.actionIcon = actionIcon
        self.showBadge = showBadge
        self.additionalInfo = additionalInfo()
    }
    
    init(
        icon: SettingsIcon? = nil,
        title: LocalizedStringResource,
        actionIcon: SettingsRowActionIcon? = .chevron,
        showBadge: Bool = false,
        @ViewBuilder additionalInfo: () -> AdditionalInfo
    ) {
        self.init(
            icon: icon,
            title: Text(title),
            actionIcon: actionIcon,
            showBadge: showBadge,
            additionalInfo: additionalInfo
        )
    }
    
    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                SettingsIconView(icon: icon)
                    .controlSize(.small)
            }

            Group {
                if showBadge {
                    title
                        .overlay(alignment: .topTrailing) {
                            Circle()
                                .fill(.red)
                                .frame(width: 8, height: 8)
                                .offset(x: 8, y: -4)
                        }
                } else {
                    title
                }
            }
            .foregroundStyle(isEnabled ? .neutral950 : .neutral300)
            
            Spacer()
            
            HStack(spacing: Spacing.s) {
                if let additionalInfo {
                    additionalInfo
                        .foregroundStyle(.neutral500)
                        .font(.body)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .allowsTightening(true)
                        .frame(alignment: .trailing)
                }
                
                if let actionIcon {
                    Image(systemName: actionIcon.rawValue)
                        .frame(alignment: .trailing)
                        .foregroundStyle(actionIcon.color)
                }
            }
        }
        .foregroundStyle(isButtonStyle ? .accentColor : Asset.mainTextColor.swiftUIColor)
    }
    
    func titleButtonStyle() -> some View {
        var instance = self
        instance.isButtonStyle = true
        return instance
    }
}

extension SettingsRowView where AdditionalInfo == EmptyView {
    
    init(
        icon: SettingsIcon? = nil,
        title: LocalizedStringResource,
        showBadge: Bool = false,
        actionIcon: SettingsRowActionIcon? = .chevron
    ) {
        self.init(
            icon: icon,
            title: Text(title),
            actionIcon: actionIcon,
            showBadge: showBadge,
            additionalInfo: { EmptyView() })
    }
    
    init(
        icon: SettingsIcon? = nil,
        title: Text,
        actionIcon: SettingsRowActionIcon? = .chevron,
        showBadge: Bool = false
    ) {
        self.init(
            icon: icon,
            title: title,
            actionIcon: actionIcon,
            showBadge: showBadge,
            additionalInfo: { EmptyView() })
    }
}

extension SettingsRowView where AdditionalInfo == Text {
    
    init(
        icon: SettingsIcon? = nil,
        title: LocalizedStringResource,
        actionIcon: SettingsRowActionIcon? = .chevron,
        showBadge: Bool = false,
        additionalInfo: Text
    ) {
        self.init(
            icon: icon,
            title: Text(title),
            actionIcon: actionIcon,
            showBadge: showBadge,
            additionalInfo: { additionalInfo })
    }
}

#Preview {
    List {
        SettingsRowView(icon: .sync, title: "Backup", actionIcon: .chevron)
    }
}
