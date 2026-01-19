// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import AVFoundation
import UIKit.UIView
import Common

/**
 Initialize with outputs, set preview view, start preview. Then stop preview, clear. Uses back camera only with autofocus
 Additional actions are provided by Output Modules
 */
final class CameraController {
    enum CameraError: Error {
        case deviceInitialization(error: Error)
        case inputDeviceInitialization(error: Error)
        case inputDeviceRegistration
        case outputModuleRegistration(module: CameraOutputModule)
    }
    
    private var captureSession: AVCaptureSession?
    private var captureDevice: AVCaptureDevice?
    private var outputs: [CameraOutputModule] = []
    private weak var layer: AVCaptureVideoPreviewLayer?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    
    private let notificationCenter = NotificationCenter.default
    
    weak var delegate: CameraControllerDelegate?
    
    var isRunning: Bool { captureSession?.isRunning ?? false }
    private var isClearing = false
    
    private func initializationFailed(_ error: CameraError) {
        Log("CameraController - initializationFailed \(error)", module: .camera)
        delegate?.cameraFailedToInitilize(with: error)
        clear()
    }
    
    init() {}
    
    /// Use outputs for e.g. Photo or QR Code scanning
    func initialize(with outputs: [CameraOutputModule]) {
        Log("CameraController - initialize", module: .camera)
        let captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high
        
        notificationCenter.addObserver(
            self,
            selector: #selector(updateOrientation),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        
        self.outputs = outputs
        
        guard let device = AVCaptureDevice.default(for: .video) else { return }
        do {
            try device.lockForConfiguration()
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            }
            device.unlockForConfiguration()
        } catch {
            initializationFailed(.deviceInitialization(error: error))
            return
        }
        self.captureDevice = device
        
        let videoInput: AVCaptureDeviceInput
        do {
            videoInput = try AVCaptureDeviceInput(device: device)
        } catch {
            initializationFailed(.inputDeviceInitialization(error: error))
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            initializationFailed(.inputDeviceRegistration)
            return
        }
        
        for outputModule in outputs {
            guard let output = outputModule.output, captureSession.canAddOutput(output) else {
                initializationFailed(.outputModuleRegistration(module: outputModule))
                return
            }
            captureSession.addOutput(output)
            outputModule.registered()
        }
        
        self.captureSession = captureSession
        delegate?.cameraDidInitialize()
        Log("CameraController - initialize successful", module: .camera)
    }
    
    /// Set the view backed by AVCaptureViewPreviewLayer
    func setPreview(_ view: UIView) {
        guard let layer = view.layer as? AVCaptureVideoPreviewLayer
        else { fatalError("CameraController: Passed view doesn't have a AVCaptureVideoPreviewLayer backing layer") }
        layer.session = captureSession
        layer.videoGravity = .resizeAspectFill
        
        if let captureDevice {
            rotationCoordinator = AVCaptureDevice.RotationCoordinator(
                device: captureDevice,
                previewLayer: layer
            )
        }
        
        self.layer = layer
        Log("CameraController - setPreview with view: \(view)", module: .camera)
    }
    
    func startPreview() {
        guard !isRunning else { return }
        Log("CameraController - startPreview. Starting!", module: .camera)
        updateOrientation()
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession?.startRunning()
            DispatchQueue.main.async {
                self.delegate?.cameraStartedPreview()
            }
        }
    }
    
    func stopPreview() {
        guard isRunning else { return }
        Log("CameraController - stopPreview. Stopping!", module: .camera)
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
        DispatchQueue.main.async {
            self.captureSession?.stopRunning()
            self.delegate?.cameraStoppedPreview()
        }
    }
    
    /// Useful for freezing the screen for a while e.g. when simulating taking the photo
    func freezePreview() {
        Log("CameraController - freezePreview", module: .camera)
        let connection = layer?.connection
        DispatchQueue.main.async {
            connection?.isEnabled = false
            self.delegate?.cameraFreezedPreview()
        }
    }
    
    func unfreezePreview() {
        Log("CameraController - unfreezePreview", module: .camera)
        let connection = layer?.connection
        DispatchQueue.main.async {
            connection?.isEnabled = true
            self.delegate?.cameraUnfreezedPreview()
        }
    }
    
    /// Call when camera is no longer needed
    func clear() {
        Log("CameraController - clear!!!", module: .camera)
        clearSession(useAsync: true)
    }
    
    @objc
    func updateOrientation() {
        guard
            let rotationCoordinator,
            let connection = layer?.connection
        else { return }
        
        Log("CameraController - updateOrientation", module: .camera)
        
        let angle = rotationCoordinator.videoRotationAngleForHorizonLevelPreview
        
        guard connection.isVideoRotationAngleSupported(angle) else {
            Log("CameraController - orientation not supported for angle: \(angle)", module: .camera, save: false)
            return
        }
        
        Log("CameraController - setting angle: \(angle)", module: .camera, save: false)
        
        connection.videoRotationAngle = angle
    }
    
    // MARK: - Private
    
    private func clearSession(useAsync: Bool) {
        guard !isClearing else { return }
        isClearing = true
        Log("CameraController - clearSession. Use async: \(useAsync)", module: .camera)
        func removeDependencies(captureSession: AVCaptureSession, callDelegate: Bool) {
            captureSession.inputs.forEach(captureSession.removeInput)
            captureSession.outputs.forEach(captureSession.removeOutput)
            outputs.forEach { $0.clear() }
            outputs = []
            captureSession.stopRunning()
            self.captureSession = nil
            if callDelegate {
                Log("CameraController - did clear!", module: .camera)
                delegate?.cameraDidClear()
            }
        }
        
        rotationCoordinator = nil
        
        layer?.session = nil
        layer = nil
        
        guard let captureSession else {
            Log("CameraController - did clear!", module: .camera)
            outputs = []
            delegate?.cameraDidClear()
            return
        }
        
        if useAsync {
            DispatchQueue.main.async {
                removeDependencies(captureSession: captureSession, callDelegate: true)
            }
        } else {
            removeDependencies(captureSession: captureSession, callDelegate: false)
        }
        Log("CameraController - did clear!", module: .camera)
    }
    
    deinit {
        Log("CameraController - deinit!", module: .camera)
        notificationCenter.removeObserver(self)
        clearSession(useAsync: false)
    }
}
