// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit.UIApplication

enum ConnectPermissionsStepStatus: Equatable {
    case success
    case warning
    case failed
}

@Observable
final class ConnectPermissionsPresenter {
    
    private(set) var progress = 0.1
    
    enum Step {
        case camera
        case pushNotifications
    }
    
    let appSettingsURL = URL(string: UIApplication.openSettingsURLString)

    private(set) var stepsStatus: [Step: ConnectPermissionsStepStatus] = [:]
    private(set) var currentStep: Step = .camera
    private(set) var isWaitingForUser = false
    
    private let interactor: ConnectPermissionsModuleInteracting
    
    init(interactor: ConnectPermissionsModuleInteracting) {
        self.interactor = interactor
     
        refreshCameraStatus()
        refreshPushNotificationsStatus()
        
        if stepsStatus[.camera] == .success {
            currentStep = .pushNotifications
        }
    }
    
    var isFinished: Bool {
        stepsStatus[.camera] != nil && stepsStatus[.camera] != .failed && stepsStatus[.pushNotifications] != nil
    }
    
    var shouldDismiss: Bool {
        progress == 1.0
    }
    
    private func refreshCameraStatus() {
        stepsStatus[.camera] = interactor.shouldAskForCamera ? nil : (interactor.isCameraAllowed ? .success : .failed)
    }
    
    private func refreshPushNotificationsStatus() {
        stepsStatus[.pushNotifications] = interactor.shouldAskForPushNotifications ? nil : (interactor.isPushNotificationsAllowed ? .success : .warning)
    }

    @MainActor
    func onContinue() {
        isWaitingForUser = true
        
        switch currentStep {
        case .camera:
            Task {
                await interactor.requestCameraPermission()
                
                refreshCameraStatus()
                                
                if stepsStatus[.camera] == .success {
                    if stepsStatus[.pushNotifications] == nil {
                        currentStep = .pushNotifications
                        progress = 0.5
                    } else {
                        progress = 1.0
                    }
                }
                
                isWaitingForUser = false
            }
            
        case .pushNotifications:
            Task {
                await interactor.requestPushNotificationsPermission()
                
                refreshPushNotificationsStatus()
                progress = 1.0
                isWaitingForUser = false
            }
        }
    }
    
    func finishOnboarding() {
        interactor.finishOnboarding()
    }
}
