// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import Data

protocol GenerateContentModuleInteracting: AnyObject {
    var passwordCount: Int { get }
    func generatePasswords(count: Int, completion: @escaping Callback)
    func removeAllPasswords()
}

final class GenerateContentModuleInteractor {
    private let debugInteractor: DebugInteracting
    private let syncChangeTriggerInteractor: SyncChangeTriggerInteracting
    
    init(debugInteractor: DebugInteracting, syncChangeTriggerInteractor: SyncChangeTriggerInteracting) {
        self.debugInteractor = debugInteractor
        self.syncChangeTriggerInteractor = syncChangeTriggerInteractor
    }
}

extension GenerateContentModuleInteractor: GenerateContentModuleInteracting {
    var passwordCount: Int {
        debugInteractor.passwordCount
    }
    
    func generatePasswords(count: Int, completion: @escaping Callback) {
        debugInteractor.generatePasswords(count: count, completion: completion)
        syncChangeTriggerInteractor.trigger()
    }
    
    func removeAllPasswords() {
        debugInteractor.deleteAllPasswords()
        syncChangeTriggerInteractor.trigger()
    }
}
