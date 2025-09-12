// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public enum UpdateAppPromptRequestReason {
    case webDAVSchemeNotSupported(schemeVersion: Int, expectedVersion: Int)
    case iCloudSchemeNotSupported(schemeVersion: Int, expectedVersion: Int)
}

public enum UpdateAppPromptState {
    case hidden
    case unsupportedAppVersion(minimalVersion: String)
}

public protocol UpdateAppPromptInteracting: AnyObject {
    
    var appVersionPromptState: UpdateAppPromptState { get }
    
    func markPromptAsShown()
}

final class UpdateAppPromptInteractor: UpdateAppPromptInteracting {
    
    private let mainRepository: MainRepository
    private let systemInteractor: SystemInteracting
    private let notificationCenter: NotificationCenter
    private let promptInterval: TimeInterval = 60 * 60 * 24
    
    init(mainRepository: MainRepository, systemInteractor: SystemInteracting) {
        self.mainRepository = mainRepository
        self.systemInteractor = systemInteractor
        self.notificationCenter = NotificationCenter.default
        
        startMonitoring()
    }

    var appVersionPromptState: UpdateAppPromptState {
        guard let minimalVersion = mainRepository.minimalAppVersionSupported else {
            return .hidden
        }
        let currentVersion = systemInteractor.appVersion
        if isVersion(currentVersion, olderThan: minimalVersion) && shouldShowPrompt() {
            return .unsupportedAppVersion(minimalVersion: minimalVersion)
        } else {
            return .hidden
        }
    }
    
    func markPromptAsShown() {
        mainRepository.setLastAppUpdatePromptDate(Date())
    }
    
    deinit {
        stopMonitoring()
    }
}

private extension UpdateAppPromptInteractor {
    
    func startMonitoring() {
        notificationCenter.addObserver(
            self,
            selector: #selector(handleWebDAVStateChange(_:)),
            name: .webDAVStateChange,
            object: nil
        )
        Log("UpdateAppPromptInteractor - Started monitoring WebDAV state changes", module: .interactor)
    }
    
    func stopMonitoring() {
        notificationCenter.removeObserver(self)
        Log("UpdateAppPromptInteractor - Stopped monitoring WebDAV state changes", module: .interactor)
    }
    
    @objc func handleWebDAVStateChange(_ notification: Notification) {
        guard let state = notification.userInfo?[Notification.webDAVState] as? WebDAVState else {
            return
        }
        
        if shouldShowPrompt() {
            switch state {
            case .error(.schemaNotSupported(let schemeVersion, let expectedVersion)):
                Log("UpdateAppPromptInteractor - Scheme not supported detected (v\(schemeVersion), expected v\(expectedVersion)), showing update prompt", module: .interactor)
                
                Task { @MainActor in
                    self.postUpdatePromptNotification(.webDAVSchemeNotSupported(schemeVersion: schemeVersion, expectedVersion: expectedVersion))
                }
            default:
                break
            }
        }
    }
    
    func shouldShowPrompt() -> Bool {
        guard let lastPromptDate = mainRepository.lastAppUpdatePromptDate else {
            return true
        }
        
        let timeSinceLastPrompt = Date().timeIntervalSince(lastPromptDate)
        return timeSinceLastPrompt >= promptInterval
    }
    
    func isVersion(_ version1: String, olderThan version2: String) -> Bool {
        let v1Components = version1.split(separator: ".").compactMap { Int($0) }
        let v2Components = version2.split(separator: ".").compactMap { Int($0) }
        
        let maxLength = max(v1Components.count, v2Components.count)
        for i in 0..<maxLength {
            let v1Value = i < v1Components.count ? v1Components[i] : 0
            let v2Value = i < v2Components.count ? v2Components[i] : 0
            
            if v1Value < v2Value {
                return true
            } else if v1Value > v2Value {
                return false
            }
        }
        
        return false
    }
    
    func postUpdatePromptNotification(_ state: UpdateAppPromptRequestReason) {
        notificationCenter.post(
            name: .showUpdateAppPrompt,
            object: nil,
            userInfo: [Notification.showUpdateAppPromptReasonKey: state]
        )
    }
}
