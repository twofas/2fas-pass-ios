// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Data

protocol ConnectPermissionsModuleInteracting: AnyObject {
    var shouldAskForCamera: Bool { get }
    var shouldAskForPushNotifications: Bool { get }
    
    var isCameraAllowed: Bool { get }
    var isPushNotificationsAllowed: Bool { get }

    func requestCameraPermission() async
    func requestPushNotificationsPermission() async
    
    func finishOnboarding()
}

final class ConnectPermissionsModuleInteractor: ConnectPermissionsModuleInteracting {
    
    private let cameraPermissionInteractor: CameraPermissionInteracting
    private let pushNotificationsPermissionInteractor: PushNotificationsPermissionInteracting
    private let connectOnboardingInteractor: ConnectOnboardingInteracting
    
    init(cameraPermissionInteractor: CameraPermissionInteracting, pushNotificationsPermissionInteractor: PushNotificationsPermissionInteracting, connectOnboardingInteractor: ConnectOnboardingInteracting) {
        self.cameraPermissionInteractor = cameraPermissionInteractor
        self.pushNotificationsPermissionInteractor = pushNotificationsPermissionInteractor
        self.connectOnboardingInteractor = connectOnboardingInteractor
    }
    
    var shouldAskForCamera: Bool {
        cameraPermissionInteractor.cameraPermission
    }
    
    var isCameraAllowed: Bool {
        cameraPermissionInteractor.isCameraAllowed
    }
    
    var shouldAskForPushNotifications: Bool {
        pushNotificationsPermissionInteractor.canRequestForPermissions
    }
    
    var isPushNotificationsAllowed: Bool {
        pushNotificationsPermissionInteractor.isEnabled
    }
    
    func requestCameraPermission() async {
        await withCheckedContinuation { continuation in
            cameraPermissionInteractor.register { _ in
                continuation.resume()
            }
        }
    }
    
    func requestPushNotificationsPermission() async {
        await pushNotificationsPermissionInteractor.requestForPermissions()
    }
    
    func finishOnboarding() {
        connectOnboardingInteractor.finishOnboarding()
    }
}
