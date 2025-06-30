// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public protocol AppStateInteracting: AnyObject {
    var isLockScreenActive: Bool { get }
    
    func lockScreenActive()
    func lockScreenInactive()
}

final class AppStateInteractor {
    private let mainRepository: MainRepository
    
    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }
}

extension AppStateInteractor: AppStateInteracting {
    var isLockScreenActive: Bool {
        mainRepository.isLockScreenActive
    }
    
    func lockScreenActive() {
        Log("AppStateInteractor: Locking screen", module: .interactor)
        mainRepository.lockScreenActive()
    }
    
    func lockScreenInactive() {
        Log("AppStateInteractor: Unlocking screen", module: .interactor)
        mainRepository.lockScreenInactive()
    }
}
