// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

@Observable
final class WiFiNetworkQRCodePresenter {
    let ssid: String
    private let payload: String
    var qrCodeImage: Image?

    init(ssid: String, payload: String) {
        self.ssid = ssid
        self.payload = payload
    }

    func onAppear() {
        guard qrCodeImage == nil else {
            return
        }
        qrCodeImage = makeQRCodeImage(from: payload)
    }
}

private extension WiFiNetworkQRCodePresenter {
    
    func makeQRCodeImage(from data: String) -> Image? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(data.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else {
            return nil
        }

        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        let context = CIContext()

        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
            return nil
        }

        return Image(decorative: cgImage, scale: 1, orientation: .up)
    }
}
