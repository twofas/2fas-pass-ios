// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

private struct Constants {
    static let titleLineLimit = 3
    static let fallbackIconSize: CGFloat = 36
    static let qrCodeSize: CGFloat = 200
}

struct WiFiNetworkQRCodeView: View {
    @State
    var presenter: WiFiNetworkQRCodePresenter

    @Environment(\.dismiss)
    private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()

                VStack(spacing: Spacing.xl) {
                    Text(String(localized: .wifiQrJoinTitle(presenter.ssid)))
                        .font(.title1Emphasized)
                        .foregroundStyle(.base1000)
                        .multilineTextAlignment(.center)
                        .lineLimit(Constants.titleLineLimit)

                    if let qrCodeImage = presenter.qrCodeImage {
                        qrCodeImage
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: Constants.qrCodeSize, height: Constants.qrCodeSize)
                    } else {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: Constants.fallbackIconSize, weight: .semibold))
                            .foregroundStyle(.neutral500)
                    }
                }
                .padding(.horizontal, Spacing.xl)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: UIDevice.isiPad ? .center : .top)
                .ignoresSafeArea(UIDevice.isiPad ? .container : [], edges: .top)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarCancelButton {
                        dismiss()
                    }
                }
            }
            .onAppear {
                presenter.onAppear()
            }
        }
    }
}
