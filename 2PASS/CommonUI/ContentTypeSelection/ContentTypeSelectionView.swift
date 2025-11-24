// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct ContentTypeSelectionView: View {

    let onSelect: (ItemContentType) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(ItemContentType.allKnownTypes, id: \.rawValue) { option in
                ContentTypeRow(option: option) {
                    onSelect(option)
                }
            }
        }
        .padding(.horizontal, Spacing.s)
        .padding(.vertical, Spacing.l)
    }
}

#Preview {
    Color.red
        .sheet(isPresented: .constant(true)) {
            ContentTypeSelectionView(onSelect: { _ in }, onClose: {})
                .presentationDetents([.medium])
                .presentationBackgroundInteraction(.disabled)
        }
}

private struct ContentTypeOption {
    let contentType: ItemContentType
    let title: String
}

private struct ContentTypeRow: View {
    let option: ItemContentType
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: Spacing.m) {
                ZStack {
                    Circle()
                        .fill(Color(option.primaryColor))
                        .frame(width: 40, height: 40)
                    
                    if let icon = option.icon {
                        Image(uiImage: icon)
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .foregroundStyle(.white)
                    }
                }
                
                Text(option, format: .itemContentType)
                    .font(.system(size: 17))
                    .foregroundStyle(Asset.mainTextColor.swiftUIColor)
                
                Spacer()
            }
            .padding(.horizontal, Spacing.l)
            .padding(.vertical, Spacing.m)
            .contentShape(Rectangle())
        }
        .buttonStyle(MenuButtonStyle())
    }
}

private struct MenuButtonStyle: ButtonStyle {
    
    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26.0, *) {
            configuration.label
                .glassEffect(configuration.isPressed ? .regular.interactive() : .identity.interactive())
        } else {
            configuration.label
        }
    }
}
