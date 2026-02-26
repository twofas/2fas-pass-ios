// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct WiFiNetworkQRCodeRouter {
    static func buildView(ssid: String, payload: String) -> some View {
        WiFiNetworkQRCodeView(
            presenter: .init(
                ssid: ssid,
                payload: payload
            )
        )
    }
}
