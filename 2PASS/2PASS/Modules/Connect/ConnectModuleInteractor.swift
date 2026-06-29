// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Data

protocol ConnectModuleInteracting: AnyObject {
    var isCameraAllowed: Bool { get }

#if DEBUG
    var isE2ECameraForced: Bool { get }
#endif
}

final class ConnectModuleInteractor: ConnectModuleInteracting {

    let cameraInteractor: CameraPermissionInteracting
    let connectOnboardingInteractor: ConnectOnboardingInteracting

#if DEBUG
    private let debugCameraInteractor: ConnectDebugCameraInteracting
#endif

#if DEBUG
    init(
        cameraInteractor: CameraPermissionInteracting,
        connectOnboardingInteractor: ConnectOnboardingInteracting,
        debugCameraInteractor: ConnectDebugCameraInteracting
    ) {
        self.cameraInteractor = cameraInteractor
        self.connectOnboardingInteractor = connectOnboardingInteractor
        self.debugCameraInteractor = debugCameraInteractor
    }
#else
    init(cameraInteractor: CameraPermissionInteracting, connectOnboardingInteractor: ConnectOnboardingInteracting) {
        self.cameraInteractor = cameraInteractor
        self.connectOnboardingInteractor = connectOnboardingInteractor
    }
#endif

    var isCameraAllowed: Bool {
        cameraInteractor.isCameraAllowed && connectOnboardingInteractor.isOnboardingCompleted
    }

#if DEBUG
    var isE2ECameraForced: Bool {
        debugCameraInteractor.isCameraForced
    }
#endif
}
