// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct SecurityTierLevelsFigureView: View {

    @State private var barTrailingInset: CGFloat = 20

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.l) {
            tierRow(
                label: .securityTiersHelpLocalFirstSectionFigureHigh,
                description: .securityTiersHelpLocalFirstSectionFigureHighDescription,
                filledCount: 3
            )

            tierRow(
                label: .securityTiersHelpLocalFirstSectionFigureMedium,
                description: .securityTiersHelpLocalFirstSectionFigureMediumDescription,
                filledCount: 2
            )

            tierRow(
                label: .securityTiersHelpLocalFirstSectionFigureLow,
                description: .securityTiersHelpLocalFirstSectionFigureLowDescription,
                filledCount: 1
            )
        }
        .onPreferenceChange(BadgeWidthPreferenceKey.self) { width in
            barTrailingInset = max(0, width / 2 - TierLevelRowView.Constants.dotSize / 2)
        }
    }

    private func tierRow(
        label: LocalizedStringResource,
        description: LocalizedStringResource,
        filledCount: Int
    ) -> some View {
        TierLevelRowView(
            label: label,
            description: description,
            filledCount: filledCount,
            barTrailingInset: barTrailingInset
        )
    }
}

// MARK: - Row

private struct TierLevelRowView: View {

    let label: LocalizedStringResource
    let description: LocalizedStringResource
    let filledCount: Int
    let barTrailingInset: CGFloat

    struct Constants {
        static let segmentGap: CGFloat = 4
        static let barHeight: CGFloat = 6
        static let dotSize: CGFloat = 10
        static let dotBorderWidth: CGFloat = 1.5
        static let badgePillHeight: CGFloat = 15
        static let arrowWidth: CGFloat = 8
        static let arrowHeight: CGFloat = 5
    }

    private let segmentColors: [Color] = [.danger500, .warning600, .success500]

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            barRow
            descriptionText
        }
    }

    // MARK: Bar

    private var barRow: some View {
        HStack(spacing: Constants.segmentGap) {
            ForEach(0..<3, id: \.self) { index in
                segment(at: index)
            }
        }
        .padding(.top, Constants.badgePillHeight + Constants.arrowHeight)
        .padding(.trailing, barTrailingInset)
    }

    private func segment(at index: Int) -> some View {
        let isFilled = index < filledCount
        let isIndicator = index == filledCount - 1
        let color = isFilled ? segmentColors[index] : Self.inactiveBarColor

        return Capsule()
            .fill(color)
            .frame(height: Constants.barHeight)
            .overlay(alignment: .trailing) {
                if isIndicator {
                    indicatorDot(color: segmentColors[index])
                        .overlay(alignment: .bottom) {
                            badgeWithArrow
                                .offset(y: -Constants.dotSize - Spacing.xxs)
                        }
                }
            }
    }

    private static let inactiveBarColor = Color(
        UIColor(light: .neutral100, dark: .black)
    )

    private static let badgeBackground = Color(
        UIColor(light: .neutral100, dark: .black)
    )

    private static let badgeText = Color(
        UIColor(light: .neutral600, dark: UIColor(hexString: "#CCCCCC")!)
    )

    // MARK: Badge

    private var badgeWithArrow: some View {
        VStack(spacing: 0) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Self.badgeText)
                .padding(.horizontal, Spacing.s)
                .frame(height: Constants.badgePillHeight)
                .background(
                    Capsule().fill(Self.badgeBackground)
                )

            DownArrowShape()
                .fill(Self.badgeBackground)
                .frame(width: Constants.arrowWidth, height: Constants.arrowHeight)
        }
        .fixedSize()
        .background(
            GeometryReader { proxy in
                Color.clear.preference(
                    key: BadgeWidthPreferenceKey.self,
                    value: proxy.size.width
                )
            }
        )
    }

    // MARK: Dot

    private func indicatorDot(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: Constants.dotSize, height: Constants.dotSize)
            .overlay(
                Circle()
                    .strokeBorder(.white, lineWidth: Constants.dotBorderWidth)
            )
            .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
    }

    // MARK: Description

    private var descriptionText: some View {
        Text(description)
            .font(.caption2)
            .foregroundStyle(.neutral800)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Preference Key

private struct BadgeWidthPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Arrow Shape

private struct DownArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: rect.width, y: 0))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.height))
            path.closeSubpath()
        }
    }
}

#Preview {
    SecurityTierLevelsFigureView()
        .padding()
}
