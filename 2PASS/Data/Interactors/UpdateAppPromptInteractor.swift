// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public enum UpdatePromptReason {
    case webDAVSchemeNotSupported(schemeVersion: Int, expectedVersion: Int)
}

public protocol UpdateAppPromptInteracting: AnyObject {
    var showPrompt: ((UpdatePromptReason) -> Void)? { get set }
}

final class UpdateAppPromptInteractor: UpdateAppPromptInteracting {
    
    private let mainRepository: MainRepository
    private let notificationCenter: NotificationCenter
    private let promptInterval: TimeInterval = 60 * 60 * 24
    
    var showPrompt: ((UpdatePromptReason) -> Void)?
    
    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
        self.notificationCenter = NotificationCenter.default
        
        startMonitoring()
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
                mainRepository.setLastAppUpdatePromptDate(Date())
                
                Task { @MainActor in
                    showPrompt?(.webDAVSchemeNotSupported(schemeVersion: schemeVersion, expectedVersion: expectedVersion))
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
}
