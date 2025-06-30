// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Data

protocol ConnectModuleInteracting: AnyObject {
    var isCameraAllowed: Bool { get }
}

final class ConnectModuleInteractor: ConnectModuleInteracting {
    
    let cameraInteractor: CameraPermissionInteracting
    let connectOnboardingInteractor: ConnectOnboardingInteracting
    
    init(cameraInteractor: CameraPermissionInteracting, connectOnboardingInteractor: ConnectOnboardingInteracting) {
        self.cameraInteractor = cameraInteractor
        self.connectOnboardingInteractor = connectOnboardingInteractor
    }
    
    var isCameraAllowed: Bool {
        cameraInteractor.isCameraAllowed && connectOnboardingInteractor.isOnboardingCompleted
    }
}
