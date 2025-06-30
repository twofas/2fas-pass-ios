// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

protocol KeychainDataSource: AnyObject {
    func saveBiometryFingerprint(_ data: Data)
    func clearBiometryFingerpring()
    var biometryFingerpring: Data? { get }
    
    var masterKey: MasterKeyEncrypted? { get }
    func saveMasterKey(_ key: MasterKeyEncrypted)
    func clearMasterKey()
    
    var biometryKey: BiometryKey? { get }
    func saveBiometryKey(_ data: BiometryKey)
    func clearBiometryKey()
    
    var appKey: Data? { get }
    func saveAppKey(_ data: Data)
    func clearAppKey()

    var encryptionReference: Data? { get }
    func saveEncryptionReference(_ data: Data)
    func clearEncryptionReference()

    var masterKeyEntropy: Entropy? { get }
    func saveMasterKeyEntropy(_ data: Entropy)
    func clearMasterKeyEntropy()
}
