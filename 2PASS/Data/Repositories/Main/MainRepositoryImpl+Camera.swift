// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

extension MainRepositoryImpl {
    var permission: CameraPermissionState {
        cameraPermissions
            .permission
            .toCameraPermissionState
    }
    
    var isCameraPresent: Bool {
        cameraPermissions.isCameraPresent
    }
    
    func checkForPermission() -> CameraPermissionState {
        cameraPermissions
            .checkForPermission()
            .toCameraPermissionState
    }
        
    func requestPermission(result: @escaping (CameraPermissionState) -> Void) {
        cameraPermissions.requestPermission { state in
            result(state.toCameraPermissionState)
        }
    }
}
