// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import KeychainAccess
import Common

final class KeychainDataSourceImpl {
    private let keychain = Keychain(service: "TWOPASS", accessGroup: Config.keychainGroup)
            .synchronizable(false)
            .accessibility(.afterFirstUnlockThisDeviceOnly)
    
    private let sharedKeychain = Keychain(service: "TWOPASS", accessGroup: Config.keychainSharedGroup)
            .synchronizable(false)
            .accessibility(.afterFirstUnlockThisDeviceOnly)
    
    private enum Keys: String, CaseIterable {
        case biometryFingerpring
        case masterKey
        case biometryKey
        case appKey
        case encryptionReference
        case masterKeyEntropy
    }
}

extension KeychainDataSourceImpl: KeychainDataSource {
    
    // MARK: Biometry Fingerprint
    
    func saveBiometryFingerprint(_ data: Data) {
        keychain[data: Keys.biometryFingerpring.rawValue] = data
    }
    
    func clearBiometryFingerpring() {
        try? keychain.remove(Keys.biometryFingerpring.rawValue)
    }
    
    var biometryFingerpring: Data? {
        keychain[data: Keys.biometryFingerpring.rawValue]
    }
    
    // MARK: Master Key
    
    var masterKey: MasterKeyEncrypted? {
        sharedKeychain[data: Keys.masterKey.rawValue]
    }
    
    func saveMasterKey(_ key: MasterKeyEncrypted) {
        sharedKeychain[data: Keys.masterKey.rawValue] = key
    }
    
    func clearMasterKey() {
        try? sharedKeychain.remove(Keys.masterKey.rawValue)
    }
    
    // MARK: App Key
    
    var appKey: Data? {
        sharedKeychain[data: Keys.appKey.rawValue]
    }
    
    func saveAppKey(_ data: Data) {
        sharedKeychain[data: Keys.appKey.rawValue] = data
    }
    
    func clearAppKey() {
        try? sharedKeychain.remove(Keys.appKey.rawValue)
    }
    
    // MARK: Biometry Key
    
    var biometryKey: BiometryKey? {
        sharedKeychain[data: Keys.biometryKey.rawValue]
    }
    
    func saveBiometryKey(_ data: BiometryKey) {
        sharedKeychain[data: Keys.biometryKey.rawValue] = data
    }
    
    func clearBiometryKey() {
        try? sharedKeychain.remove(Keys.biometryKey.rawValue)
    }
    
    // MARK: Encryption Reference

    var encryptionReference: Data? {
        sharedKeychain[data: Keys.encryptionReference.rawValue]
    }
    
    func saveEncryptionReference(_ data: Data) {
        sharedKeychain[data: Keys.encryptionReference.rawValue] = data
    }

    func clearEncryptionReference() {
        try? sharedKeychain.remove(Keys.encryptionReference.rawValue)
    }
    
    // MARK: Master Key Entropy

    var masterKeyEntropy: Entropy? {
        sharedKeychain[data: Keys.masterKeyEntropy.rawValue]
    }
    
    func saveMasterKeyEntropy(_ data: Entropy) {
        sharedKeychain[data: Keys.masterKeyEntropy.rawValue] = data
    }
    
    func clearMasterKeyEntropy() {
        try? sharedKeychain.remove(Keys.masterKeyEntropy.rawValue)
    }
}
