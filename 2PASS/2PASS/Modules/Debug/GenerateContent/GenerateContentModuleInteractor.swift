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
    var paymentCardsCount: Int { get }
    var tagsCount: Int { get }
    func generateItems(count: Int, completion: @escaping Callback)
    func generateSecureNotes(count: Int, completion: @escaping Callback)
    func generateUnknown(count: Int, completion: @escaping Callback)
    func generatePaymentCards(count: Int, completion: @escaping Callback)
    func removeAllItems()
    func removeAllTags()
}

final class GenerateContentModuleInteractor {
    private let debugInteractor: DebugInteracting
    private let syncTriggerInteractor: BackupSyncTriggerInteracting
    
    init(debugInteractor: DebugInteracting, syncTriggerInteractor: BackupSyncTriggerInteracting) {
        self.debugInteractor = debugInteractor
        self.syncTriggerInteractor = syncTriggerInteractor
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

    var tagsCount: Int {
        debugInteractor.tagsCount
    }

    var paymentCardsCount: Int {
        debugInteractor.paymentCardsCount
    }

    func generateItems(count: Int, completion: @escaping Callback) {
        debugInteractor.generateItems(count: count, completion: completion)
        syncTriggerInteractor.syncAll()
    }

    func generateSecureNotes(count: Int, completion: @escaping Callback) {
        debugInteractor.generateSecureNotes(count: count, completion: completion)
        syncTriggerInteractor.syncAll()
    }

    func generateUnknown(count: Int, completion: @escaping Callback) {
        debugInteractor.generateUnknown(count: count, completion: completion)
        syncTriggerInteractor.syncAll()
    }

    func generatePaymentCards(count: Int, completion: @escaping Callback) {
        debugInteractor.generatePaymentCards(count: count, completion: completion)
        syncTriggerInteractor.syncAll()
    }

    func removeAllItems() {
        debugInteractor.deleteAllItems()
        syncTriggerInteractor.syncAll()
    }

    func removeAllTags() {
        debugInteractor.deleteAllTags()
        syncTriggerInteractor.syncAll()
    }
}
