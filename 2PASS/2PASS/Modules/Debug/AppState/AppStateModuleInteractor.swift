// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

protocol AppStateModuleInteracting: AnyObject {
    // MARK: - Has value
    
    var hasDeviceID: Bool { get }
    var hasSelectedVault: Bool { get }
    var isInMemoryStorageActive: Bool { get }
    var hasStoredMasterKey: Bool { get }
    var hasBiometryKey: Bool { get }
    var hasAppKey: Bool { get }
    var hasSeed: Bool { get }
    var hasInMemoryEntropy: Bool { get }
    var hasWords: Bool { get }
    var hasSalt: Bool { get }
    var hasMasterPassword: Bool { get }
    var hasInMemoryMasterKey: Bool { get }
    var hasEncryptionReference: Bool { get }
    var hasStoredEntropy: Bool { get }
    var hasTrustedKey: Bool { get }
    var hasSecureKey: Bool { get }
    var hasExternalKey: Bool { get }
    
    // MARK: - Value
    
    var deviceID: DeviceID? { get }
    var selectedVaultID: VaultID? { get }
    var storedMasterKey: MasterKey? { get }
    var seed: Seed? { get }
    var inMemoryEntropy: Entropy? { get }
    var words: [String]? { get }
    var salt: Data? { get }
    var masterPassword: MasterPassword? { get }
    var inMemoryMasterKey: MasterKey? { get }
    var storedEntropy: Entropy? { get }
    var trustedKey: TrustedKey? { get }
    var secureKey: SecureKey? { get }
    var externalKey: ExternalKey? { get }
}

final class AppStateModuleInteractor {
    private let debugInteractor: DebugInteracting
    
    init(debugInteractor: DebugInteracting) {
        self.debugInteractor = debugInteractor
    }
}

extension AppStateModuleInteractor: AppStateModuleInteracting {
    var hasDeviceID: Bool { debugInteractor.hasDeviceID }
    var hasSelectedVault: Bool { debugInteractor.hasSelectedVault }
    var isInMemoryStorageActive: Bool { debugInteractor.isInMemoryStorageActive }
    var hasStoredMasterKey: Bool { debugInteractor.hasStoredMasterKey }
    var hasBiometryKey: Bool { debugInteractor.hasBiometryKey }
    var hasAppKey: Bool { debugInteractor.hasAppKey }
    var hasSeed: Bool { debugInteractor.hasSeed }
    var hasInMemoryEntropy: Bool { debugInteractor.hasInMemoryEntropy }
    var hasWords: Bool { debugInteractor.hasWords }
    var hasSalt: Bool { debugInteractor.hasSalt }
    var hasMasterPassword: Bool { debugInteractor.hasMasterPassword }
    var hasInMemoryMasterKey: Bool { debugInteractor.hasInMemoryMasterKey }
    var hasEncryptionReference: Bool { debugInteractor.hasEncryptionReference }
    var hasStoredEntropy: Bool { debugInteractor.hasStoredEntropy }
    var hasTrustedKey: Bool { debugInteractor.hasTrustedKey }
    var hasSecureKey: Bool { debugInteractor.hasSecureKey }
    var hasExternalKey: Bool { debugInteractor.hasExternalKey }
    
    // MARK: - Value
    
    var deviceID: DeviceID? { debugInteractor.deviceID }
    var selectedVaultID: VaultID? { debugInteractor.selectedVaultID }
    var storedMasterKey: MasterKey? { debugInteractor.storedMasterKey }
    var seed: Seed? { debugInteractor.seed }
    var inMemoryEntropy: Entropy? { debugInteractor.inMemoryEntropy }
    var words: [String]? { debugInteractor.words }
    var salt: Data? { debugInteractor.salt }
    var masterPassword: MasterPassword? { debugInteractor.masterPassword }
    var inMemoryMasterKey: MasterKey? { debugInteractor.inMemoryMasterKey }
    var storedEntropy: Entropy? { debugInteractor.storedEntropy }
    var trustedKey: TrustedKey? { debugInteractor.trustedKey }
    var secureKey: SecureKey? { debugInteractor.secureKey }
    var externalKey: ExternalKey? { debugInteractor.externalKey }
}
