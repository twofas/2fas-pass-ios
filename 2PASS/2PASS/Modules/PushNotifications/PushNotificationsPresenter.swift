// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

@Observable
final class PushNotificationsPresenter {
    
    private let interactor: PushNotificationsModuleInteracting
    
    var status: String {
        isEnabled ? T.commonEnabled : T.commonDisabled
    }
    
    private(set) var canRequestForPermissions: Bool
    private(set) var isEnabled: Bool
    
    init(interactor: PushNotificationsModuleInteracting) {
        self.interactor = interactor
        
        self.canRequestForPermissions = interactor.canRequestForPermissions
        self.isEnabled = interactor.isEnabled
    }
    
    func observePushNotificationsStatusChanged() async {
        for await _ in interactor.didStatusChanged {
            refreshStatus()
        }
    }
    
    var systemSettingsURL: URL? {
        interactor.systemSettingsURL
    }
    
    func turnOn() {
        guard interactor.canRequestForPermissions else {
            return
        }
            
        Task {
            await interactor.requestForPermissions()
        }
    }
    
    private func refreshStatus() {
        canRequestForPermissions = interactor.canRequestForPermissions
        isEnabled = interactor.isEnabled
    }
}
