// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Data
import Common

struct WiFiNetworkQRCodeScannerRouter {
    static func buildView(
        onScanned: @escaping (WiFiQRCodeData) -> Void
    ) -> some View {
        WiFiNetworkQRCodeScannerView(
            presenter: .init(
                onScanned: onScanned,
                cameraPermissionInteractor: InteractorFactory.shared.cameraPermissionsInteractor(),
                wifiQRCodeInteractor: InteractorFactory.shared.wifiQRCodeInteractor()
            )
        )
    }
}
