// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import AVFoundation
import Common

public final class CameraPermissions {
    public enum PermissionState {
        case unknown
        case granted
        case denied
        case error
    }
    
    public private(set) var permission: PermissionState = .unknown
    
    public func checkForPermission() -> PermissionState {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        Log("CameraPermissions - checkForPermission: \(status)", module: .camera)
        switch status {
        case .authorized:
            permission = .granted
        case .denied, .restricted:
            permission = .denied
        case .notDetermined:
            permission = .unknown
        @unknown default:
            print("Unknown auth status for AV Capture Device")
        }
        
        return permission
    }
    
    public var isCameraPresent: Bool { AVCaptureDevice.default(for: .video) != nil }
    
    public func requestPermission(result: @escaping (PermissionState) -> Void) {
        Log("CameraPermissions - requestPermission: - isCameraPresent: \(isCameraPresent)", module: .camera)
        guard isCameraPresent else {
            permission = .error
            result(permission)
            return
        }
        
        // swiftlint:disable line_length
        Log("CameraPermissions - requestPermission: - authorizationStatus: \(AVCaptureDevice.authorizationStatus(for: .video))", module: .camera)
        // swiftlint:enable line_length
        
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permission = .granted
            result(permission)
            return
        case .restricted, .denied:
            permission = .denied
            result(permission)
            return
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { [weak self] granted in
                guard let self else { return }
                Log("CameraPermissions - requestPermission for not determined. Granded: \(granted)", module: .camera)
                DispatchQueue.main.async {
                    if granted {
                        self.permission = .granted
                    } else {
                        self.permission = .denied
                    }
                    
                    result(self.permission)
                }
            })
        @unknown default:
            print("Unknown AV Capture device status")
        }
    }
}
