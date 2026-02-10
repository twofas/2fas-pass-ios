// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import AVFoundation
import Common

public final class Camera {
    private let camera = CameraController()
    private let scanner = CameraOutputQRScanner()
    private var isScanning = false
    
    public weak var delegate: CameraDelegate?
    
    public init(previewView: UIView, scanningRegion: CGRect) {
        Log("Camera - init with previewView: \(previewView.description), scanningRegion: \(scanningRegion.debugDescription, privacy: .public)", module: .camera)
        camera.delegate = self
        scanner.didFoundCode = { [weak self] in self?.delegate?.didFoundCode($0) }
        scanner.didLoseCode = { [weak self] in self?.delegate?.didLoseCode() }
        scanner.initialize(with: previewView)
        camera.initialize(with: [scanner])
        camera.setPreview(previewView)
        scanner.setScanningRect(scanningRegion)
    }
    
    public func updateScanningRegion(_ scanningRegion: CGRect) {
        Log("Camera - updateScanningRegion \(scanningRegion.debugDescription, privacy: .public)", module: .camera)
        scanner.setScanningRect(scanningRegion)
    }
    
    public func startScanning() {
        Log("Camera - startScanning", module: .camera)
        camera.startPreview()
    }
    
    public func stopScanning() {
        Log("Camera - stopScanning", module: .camera)
        camera.stopPreview()
    }
    
    public func freeze() {
        Log("Camera - freeze", module: .camera)
        camera.freezePreview()
    }
    
    public func unfreeze() {
        Log("Camera - unfreeze", module: .camera)
        camera.unfreezePreview()
    }
    
    public func updateOrientation() {
        Log("Camera - updateOrientation", module: .camera)
        camera.updateOrientation()
    }
    
    public func clear() {
        Log("Camera - clear", module: .camera)
        camera.clear()
    }
    
    deinit {
        Log("Camera - deinit and clear!", module: .camera)
        camera.clear()
    }
}

extension Camera: CameraControllerDelegate {
    func cameraDidInitialize() {}
    func cameraFailedToInitilize(with error: CameraController.CameraError) {
        Log("Camera - can't start: \(error)", module: .camera)
    }
    func cameraStartedPreview() {
        delegate?.didStartScanning()
    }
    func cameraStoppedPreview() {}
    func cameraFreezedPreview() {}
    func cameraUnfreezedPreview() {}
    func cameraDidClear() {}
}
