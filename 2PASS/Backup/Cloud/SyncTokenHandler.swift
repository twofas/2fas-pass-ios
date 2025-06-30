// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CloudKit
import Common

final class SyncTokenHandler {
    private var databaseChangeToken: CKServerChangeToken?
    private var zoneChangeToken: CKServerChangeToken?
    private var notificationsInitiated: Bool?
    private var zoneInitiated: Bool?
    
    func setDatabaseChangeToken(_ databaseChangeToken: CKServerChangeToken) {
        Log("SyncTokenHandler: - setDatabaseChangeToken", module: .cloudSync)
        self.databaseChangeToken = databaseChangeToken
    }
    
    func setZoneChangeToken(_ zoneChangeToken: CKServerChangeToken) {
        Log("SyncTokenHandler: - setZoneChangeToken", module: .cloudSync)
        self.zoneChangeToken = zoneChangeToken
    }
    
    func setNotificationsInitiated() {
        Log("SyncTokenHandler: - setNotificationsInitiated", module: .cloudSync)
        self.notificationsInitiated = true
    }
    
    func setZoneInitiated() {
        Log("SyncTokenHandler: - zoneInitiated", module: .cloudSync)
        self.zoneInitiated = true
    }
    
    func commitChanges() {
        Log("SyncTokenHandler: - commitChanges", module: .cloudSync)
        
        if let databaseChangeToken {
            ConstStorage.databaseChangeToken = databaseChangeToken
        }
        if let zoneChangeToken {
            ConstStorage.zoneChangeToken = zoneChangeToken
        }
        if let notificationsInitiated {
            ConstStorage.notificationsInitiated = notificationsInitiated
        }
        if let zoneInitiated {
            ConstStorage.zoneInitiated = zoneInitiated
        }
        
        clearAll()
    }
    
    func clearZone() {
        Log("SyncTokenHandler: - clear zone", module: .cloudSync)
        clearAll()
        ConstStorage.clearZone()
    }
    
    func prepare() {
        Log("SyncTokenHandler: - prepare", module: .cloudSync)
        clearAll()
    }
    
    private func clearAll() {
        databaseChangeToken = nil
        zoneChangeToken = nil
        notificationsInitiated = nil
        zoneInitiated = nil
    }
}
