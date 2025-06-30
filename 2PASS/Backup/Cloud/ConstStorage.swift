// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CloudKit

enum ConstStorage {
    private static let KeyDatabaseChangeToken = "KeyDatabaseChangeToken"
    private static let KeyZoneChangeToken = "KeyZoneChangeToken"
    private static let KeyZoneInitiated = "KeyZoneInitiated"
    private static let KeyNotificationsInitiated = "KeyNotificationsInitiated"
    private static let KeyUsername = "KeyCloudUsername"
    private static let KeyCloudEnabled = "KeyCloudEnabled"
    private static let KeyPasswordWasChanged = "KeyPasswordWasChanged"
    
    private static let userDefaults = UserDefaults.standard
    
    static var databaseChangeToken: CKServerChangeToken? {
        get {
            guard let tokenData = userDefaults.object(forKey: KeyDatabaseChangeToken) as? Data else { return nil }
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: tokenData)
        }
        
        set {
            guard
                let newValue,
                let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true)
            else {
                userDefaults.setValue(nil, forKey: KeyDatabaseChangeToken)
                userDefaults.synchronize()
                return
            }
            
            userDefaults.set(data, forKey: KeyDatabaseChangeToken)
            userDefaults.synchronize()
        }
    }
    
    static var zoneChangeToken: CKServerChangeToken? {
        get {
            guard let tokenData = userDefaults.object(forKey: KeyZoneChangeToken) as? Data else { return nil }
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: tokenData)
        }
        
        set {
            guard
                let newValue,
                let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true)
            else {
                userDefaults.setValue(nil, forKey: KeyZoneChangeToken)
                userDefaults.synchronize()
                return
            }
            
            userDefaults.set(data, forKey: KeyZoneChangeToken)
            userDefaults.synchronize()
        }
    }
    
    static var notificationsInitiated: Bool {
        get { userDefaults.bool(forKey: KeyNotificationsInitiated) }
        
        set {
            userDefaults.set(newValue, forKey: KeyNotificationsInitiated)
            userDefaults.synchronize()
        }
    }
    
    static var zoneInitiated: Bool {
        get { userDefaults.bool(forKey: KeyZoneInitiated) }
        
        set {
            userDefaults.set(newValue, forKey: KeyZoneInitiated)
            userDefaults.synchronize()
        }
    }
    
    static var cloudEnabled: Bool {
        get { userDefaults.bool(forKey: KeyCloudEnabled) }
        
        set {
            userDefaults.set(newValue, forKey: KeyCloudEnabled)
            userDefaults.synchronize()
        }
    }
    
    static var passwordWasChanged: Bool {
        get { userDefaults.bool(forKey: KeyPasswordWasChanged) }
        
        set {
            userDefaults.set(newValue, forKey: KeyPasswordWasChanged)
            userDefaults.synchronize()
        }
    }
    
    static func clearZone() {
        notificationsInitiated = false
        zoneInitiated = false
        zoneChangeToken = nil
        databaseChangeToken = nil
    }
    
    static var username: String? {
        get { userDefaults.string(forKey: KeyUsername) }
        
        set {
            userDefaults.set(newValue, forKey: KeyUsername)
            userDefaults.synchronize()
        }
    }
}
