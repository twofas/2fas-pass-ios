// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

public protocol CameraPermissionInteracting: AnyObject, PermissionsStateChildDataControllerProtocol {
    var cameraPermission: Bool { get }
    var isCameraAvailable: Bool { get }
    var isCameraAllowed: Bool { get }
    func checkPermission(result: @escaping ((Bool) -> Void))
    func register(callback: ((CameraPermissionState) -> Void)?)
    func checkState()
}

final class CameraPermissionInteractor {
    private let mainRepository: MainRepository
    
    var cameraPermission: Bool { mainRepository.permission == .unknown }
    var isCameraAvailable: Bool { mainRepository.isCameraPresent && (cameraPermission || isCameraAllowed) }
    var isCameraAllowed: Bool {
        mainRepository.isCameraPresent && mainRepository.permission == .granted
    }
    
    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }
}

extension CameraPermissionInteractor: CameraPermissionInteracting {
    func register(callback: ((CameraPermissionState) -> Void)?) {
        mainRepository.requestPermission { state in
            Log("CameraPermissionInteractor. Camera register - request permission: \(state)", module: .interactor)
            callback?(state)
        }
    }
    
    func checkPermission(result: @escaping ((Bool) -> Void)) {
        Log("CameraPermissionInteractor - checkPermission", module: .interactor)
        if isCameraAllowed {
            Log("CameraPermissionInteractor - camera allowed", module: .interactor)
            result(true)
            return
        }
        
        Log("CameraPermissionInteractor - requestPermission", module: .interactor)
        
        mainRepository.requestPermission { state in
            guard state == .granted else {
                Log("CameraPermissionInteractor - requestPermission - failure. No access", module: .interactor)
                result(false)
                return
            }
            
            Log("CameraPermissionInteractor - requestPermission - granted!", module: .interactor)
            
            result(true)
        }
    }
    
    func checkState() {
        let state = mainRepository.checkForPermission()
        Log("CameraPermissionInteractor. Camera permission state: \(state)", module: .interactor)
    }
}
