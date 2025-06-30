// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public enum ToastStyle {
    case success
    case failure
    case info
    case warning
}

struct ToastContentView: View {
    
    let text: Text
    let style: ToastStyle
    let icon: Image?
    
    init(text: Text, style: ToastStyle, icon: Image? = nil) {
        self.text = text
        self.style = style
        self.icon = icon
    }
    
    @Environment(\.colorScheme)
    private var colorScheme
    
    var body: some View {
        HStack(spacing: Spacing.m) {
            (icon ?? defaultIcon)
                .font(.system(size: 28))
                .foregroundStyle(iconColor)
            
            text
                .font(.subheadlineEmphasized)
                .foregroundStyle(.base1000)
                .padding(.trailing, Spacing.xs)
                .lineLimit(3)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.m)
    }
    
    private var defaultIcon: Image {
        switch style {
        case .success:
            Image(systemName: "checkmark.circle.fill")
        case .failure:
            Image(systemName: "xmark.circle.fill")
        case .info:
            Image(systemName: "info.circle.fill")
        case .warning:
            Image(systemName: "exclamationmark.triangle.fill")
        }
    }
    
    private var iconColor: Color {
        switch style {
        case .success:
            return .success500
        case .warning:
            return .warning500
        case .failure:
            return .danger500
        case .info:
            return .brand500
        }
    }
}

#Preview {
    VStack(spacing: 50) {
        ToastContentView(text: Text("Success"), style: .success)
        ToastContentView(text: Text("Warning"), style: .warning)
        ToastContentView(text: Text("Failure"), style: .failure)
        ToastContentView(text: Text("Info"), style: .info)
    }
}
