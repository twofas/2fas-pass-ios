// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import Data

protocol GenerateContentModuleInteracting: AnyObject {
    var itemsCount: Int { get }
    var secureNotesCount: Int { get }
    var unknownCount: Int { get }
    func generateItems(count: Int, completion: @escaping Callback)
    func generateSecureNotes(count: Int, completion: @escaping Callback)
    func generateUnknown(count: Int, completion: @escaping Callback)
    func removeAllItems()
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

    var itemsCount: Int {
        debugInteractor.itemsCount
    }

    var secureNotesCount: Int {
        debugInteractor.secureNotesCount
    }

    var unknownCount: Int {
        debugInteractor.unknownCount
    }

    func generateItems(count: Int, completion: @escaping Callback) {
        debugInteractor.generateItems(count: count, completion: completion)
        syncChangeTriggerInteractor.trigger()
    }

    func generateSecureNotes(count: Int, completion: @escaping Callback) {
        debugInteractor.generateSecureNotes(count: count, completion: completion)
        syncChangeTriggerInteractor.trigger()
    }

    func generateUnknown(count: Int, completion: @escaping Callback) {
        debugInteractor.generateUnknown(count: count, completion: completion)
        syncChangeTriggerInteractor.trigger()
    }

    func removeAllItems() {
        debugInteractor.deleteAllItems()
        syncChangeTriggerInteractor.trigger()
    }
}
