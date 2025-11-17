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

    @Environment(\.colorScheme)
    private var colorScheme

    private let contentTypes: [ContentTypeOption] = [
        ContentTypeOption(
            contentType: .login,
            title: "Login",
            description: "Store your password and login details.",
            iconBackgroundColor: UIColor(hexString: "#FFE4CB")!
        ),
        ContentTypeOption(
            contentType: .secureNote,
            title: "Secure Note",
            description: "Store your secure notes.",
            iconBackgroundColor: UIColor(hexString: "#DCF0FB")!
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Title and Close button header
            HStack {
                Text("Add")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Asset.mainTextColor.swiftUIColor)

                Spacer()

                CloseButton(closeAction: onClose)
            }
            .padding(.horizontal, Spacing.l)
            .padding(.top, Spacing.m)
            .padding(.bottom, Spacing.m)

            VStack(spacing: 0) {
                ForEach(Array(contentTypes.enumerated()), id: \.offset) { index, option in
                    ContentTypeRow(option: option) {
                        onSelect(option.contentType)
                    }

                    if index < contentTypes.count - 1 {
                        Divider()
                            .padding(.leading, Spacing.l + 40 + Spacing.m)
                    }
                }
            }
            .background(colorScheme == .dark ? Asset.backroundSecondary.swiftUIColor : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, Spacing.l)
            .padding(.bottom, Spacing.l)
        }
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
    let description: String
    let iconBackgroundColor: UIColor
}

private struct ContentTypeRow: View {
    let option: ContentTypeOption
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Spacing.m) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(option.iconBackgroundColor))
                        .frame(width: 40, height: 40)

                    if let icon = option.contentType.icon {
                        Image(uiImage: icon)
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .foregroundStyle(
                                option.contentType.iconColor.map { Color(uiColor: $0) } ?? Asset.mainTextColor.swiftUIColor
                            )
                    }
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(option.title)
                        .font(.system(size: 17))
                        .foregroundStyle(Asset.mainTextColor.swiftUIColor)

                    Text(option.description)
                        .font(.system(size: 13))
                        .foregroundStyle(Asset.labelSecondaryColor.swiftUIColor)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
