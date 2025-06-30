// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import AuthenticationServices

public protocol AutoFillStatusInteracting: AnyObject {
    var isEnabled: Bool { get }
    var didStatusChanged: NotificationCenter.Notifications { get }
    
    func turnOn()
    func turnOff()
    func openAutoFillSystemSettings()
}

final class AutoFillStatusInteractor: AutoFillStatusInteracting {
        
    var didStatusChanged: NotificationCenter.Notifications {
        mainRepository.didAutoFillStatusChanged
    }
    
    var isEnabled: Bool {
        mainRepository.isAutoFillEnabled
    }
    
    private let mainRepository: MainRepository
    
    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }
    
    func turnOn() {
        if #available(iOS 18.0, *) {
            Task { @MainActor in
                await mainRepository.requestAutoFillPermissions()
            }
        } else {
            openAutoFillSystemSettings()
        }
    }
    
    func turnOff() {
        openAutoFillSystemSettings()
    }
    
    func openAutoFillSystemSettings() {
        ASSettingsHelper.openCredentialProviderAppSettings()
    }
}
