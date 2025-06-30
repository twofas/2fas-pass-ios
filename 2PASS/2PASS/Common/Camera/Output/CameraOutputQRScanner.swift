// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import AVFoundation
import UIKit.UIView
import Common

final class CameraOutputQRScanner: NSObject {
    private var metadataOutput: AVCaptureMetadataOutput?
    private weak var layer: AVCaptureVideoPreviewLayer?
    
    var didFoundCode: ((String) -> Void)?
    
    override init() {}
    
    func setScanningRect(_ scanningRectangle: CGRect? = nil) {
        guard let layer = self.layer else { fatalError("To set scanning rectangle set view first") }
        guard let metadataOutput else { fatalError("To set scanning rectangle configure scanner first") }
        Log("CameraOutputQRScanner - setScanningRect \(String(describing: scanningRectangle))", module: .camera)
        if let rect = scanningRectangle, !rect.isEmpty {
            metadataOutput.rectOfInterest = layer.metadataOutputRectConverted(fromLayerRect: rect)
        }
    }
}

extension CameraOutputQRScanner: CameraOutputModule {
    var output: AVCaptureOutput? { metadataOutput }

    func initialize(with preview: UIView) {
        guard let layer = preview.layer as? AVCaptureVideoPreviewLayer else {
            fatalError("CameraOutputQRScanner: Passed view doesn't have a AVCaptureVideoPreviewLayer backing layer")
        }
        Log("CameraOutputQRScanner - initialize with \(preview)", module: .camera)
        self.layer = layer
        metadataOutput = AVCaptureMetadataOutput()
    }
    
    func registered() {
        Log("CameraOutputQRScanner - registered", module: .camera)
        metadataOutput?.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        metadataOutput?.metadataObjectTypes = [.qr]
    }
    
    func clear() {
        metadataOutput = nil
        layer = nil
    }
}

extension CameraOutputQRScanner: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard
            let metadata = metadataObjects.first,
            let readable = metadata as? AVMetadataMachineReadableCodeObject,
            let stringValue = readable.stringValue else { return }
        Log("CameraOutputQRScanner - metadataOutput (found code!) \(stringValue)", module: .camera, save: false)
        didFoundCode?(stringValue)
    }
}
