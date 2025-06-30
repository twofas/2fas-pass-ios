// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

extension Notification.Name {
    static let syncTriggerChange = Notification.Name("syncTriggerChange")
}

public protocol SyncChangeTriggerInteracting: AnyObject {
    var newChangeForSync: Callback? { get set }
    func setPasswordWasChanged()
    func trigger()
}

final class SyncChangeTriggerInteractor {
    var newChangeForSync: Callback?
    
    private let mainRepository: MainRepository
    private let notificationCenter: NotificationCenter
    
    init(mainRepository: MainRepository, callsChange: Bool) {
        self.mainRepository = mainRepository
        self.notificationCenter = NotificationCenter.default
        
        if callsChange {
            notificationCenter.addObserver(self, selector: #selector(syncChange), name: .syncTriggerChange, object: nil)
        }
    }
    
    deinit {
        notificationCenter.removeObserver(self)
    }
}

extension SyncChangeTriggerInteractor: SyncChangeTriggerInteracting {
    func setPasswordWasChanged() {
        Log("SyncChangeTriggerInteractor - password was changed", module: .interactor)
        notificationCenter.post(name: .passwordWasChanged, object: nil)
    }
    
    func trigger() {
        Log("SyncChangeTriggerInteractor - triggering", module: .interactor)
        mainRepository.webDAVSetHasLocalChanges()
        notificationCenter.post(name: .syncTriggerChange, object: nil)
    }
}

private extension SyncChangeTriggerInteractor {
    @objc
    private func syncChange() {
        Log("SyncChangeTriggerInteractor - calling the change", module: .interactor)
        newChangeForSync?()
    }
}
