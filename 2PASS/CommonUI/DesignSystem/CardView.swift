// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

private struct Constants {
    static let aspectRatio: CGFloat = 320 / 204
    static let cornerRadius: CGFloat = 16
    static let borderWidth: CGFloat = 1
    static let issuerIconSize: CGFloat = 42
    static let nameLineLimit = 2
}

public struct CardView: View {

    let issuer: PaymentCardIssuer?
    let name: String
    let cardNumberMask: String?

    public init(
        issuer: PaymentCardIssuer?,
        name: String,
        cardNumberMask: String?
    ) {
        self.issuer = issuer
        self.name = name
        self.cardNumberMask = cardNumberMask
    }

    public var body: some View {
        Image(uiImage: coverImage)
            .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Constants.cornerRadius)
                    .stroke(.neutral200, lineWidth: Constants.borderWidth)
            )
            .overlay(alignment: .topLeading) {
                Text(name)
                    .font(.title2Emphasized)
                    .lineLimit(Constants.nameLineLimit)
                    .foregroundStyle(.baseStatic0)
                    .padding(.horizontal, Spacing.xll)
                    .padding(.vertical, Spacing.xl)
            }
            .overlay(alignment: .bottomLeading) {
                if let mask = cardNumberMask {
                    Text(mask, format: .paymentCardNumberMask)
                        .font(.callout)
                        .padding(.horizontal, Spacing.xll)
                        .padding(.vertical, Spacing.xl)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                issuerIconView
                    .colorScheme(.dark)
                    .padding(.horizontal, Spacing.xl)
                    .padding(.vertical, Spacing.xl)
            }
            .foregroundStyle(.white)
            .aspectRatio(Constants.aspectRatio, contentMode: .fit)
    }

    private var coverImage: UIImage {
        issuer?.cover ?? UIImage(resource: .unknownIssuerCover)
    }

    @ViewBuilder
    private var issuerIconView: some View {
        Group {
            if let issuer {
                IconRendererView(content: .icon(issuer.icon))
                    .controlSize(.small)
            } else {
                Image(.unknownIssuerIcon)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: Constants.issuerIconSize, height: Constants.issuerIconSize)
    }
}

#Preview {
    VStack {
        CardView(
            issuer: .visa,
            name: "My Visa Card",
            cardNumberMask: "1234"
        )

        CardView(
            issuer: .mastercard,
            name: "Mastercard Gold",
            cardNumberMask: "5678"
        )

        CardView(
            issuer: nil,
            name: "Unknown Card",
            cardNumberMask: "9999"
        )
    }
    .padding()
}
