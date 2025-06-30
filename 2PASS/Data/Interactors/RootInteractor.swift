// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public protocol RootInteracting: AnyObject {
    var introductionWasShown: Bool { get }
    var storageError: ((String) -> Void)? { get set }
    
    var isUserLoggedIn: Bool { get }
    
    func initializeApp()
    func applicationWillResignActive()
    func applicationWillEnterForeground()
    func applicationDidBecomeActive()
    func applicationWillTerminate()
    
    func markIntroAsShown()
    func lockApplication()
    
    func handleDidReceiveRegistrationToken(_ token: String?)
}

final class RootInteractor {
    var storageError: ((String) -> Void)?
    
    private let mainRepository: MainRepository
    private let cameraInteractor: CameraPermissionInteracting
    private let securityInteractor: SecurityInteracting
    
    init(
        mainRepository: MainRepository,
        cameraInteractor: CameraPermissionInteracting,
        securityInteractor: SecurityInteracting
    ) {
        self.mainRepository = mainRepository
        self.cameraInteractor = cameraInteractor
        self.securityInteractor = securityInteractor
        
        mainRepository.storageError = { [weak self] error in
            self?.storageError?(error)
        }
    }
}

extension RootInteractor: RootInteracting {
    var isUserLoggedIn: Bool {
        securityInteractor.isUserLoggedIn
    }
    
    var introductionWasShown: Bool {
        mainRepository.wasIntroductionShown()
    }
    
    func initializeApp() {
        Log("RootInteractor: initialize app", module: .interactor)
        mainRepository.initialPermissionStateSetChildren([
            cameraInteractor
        ])
        mainRepository.initialPermissionStateInitialize()
    }
    
    func markIntroAsShown() {
        Log("RootInteractor: mark intro as shown", module: .interactor)
        mainRepository.setIntroductionAsShown()
        mainRepository.enableCloudBackup()
    }
    
    func lockApplication() {
        Log("RootInteractor: logout", module: .interactor)
        securityInteractor.logout()
    }
    
    func applicationWillResignActive() {
        Log("RootInteractor: App will resign active", module: .interactor)
        mainRepository.saveStorage()
    }
    
    func applicationDidEnterBackground() {
        Log("RootInteractor: app did enter background", module: .interactor)
        securityInteractor.applicationDidEnterBackground()
    }
    
    func applicationWillEnterForeground() {
        Log("RootInteractor: app will enter foreground", module: .interactor)
        securityInteractor.applicationWillEnterForeground()
        mainRepository.initialPermissionStateInitialize()
    }
    
    func applicationDidBecomeActive() {
        Log("RootInteractor: app did become active", module: .interactor)
        securityInteractor.applicationDidBecomeActive()
    }
    
    func applicationWillTerminate() {
        Log("RootInteractor: app will terminate", module: .interactor)
        mainRepository.saveStorage()
    }
    
    func handleDidReceiveRegistrationToken(_ token: String?) {
        mainRepository.savePushNotificationToken(token)
    }
}
