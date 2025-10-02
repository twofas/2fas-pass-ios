// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data

protocol ModifyStateModuleInteracting: AnyObject {
    // MARK: - Has value
    var hasDeviceID: Bool { get }
    var hasSelectedVault: Bool { get }
    var hasAppKey: Bool { get }
    var hasStoredMasterKey: Bool { get }
    var hasBiometryKey: Bool { get }
    var hasEncryptionReference: Bool { get }
    var hasStoredEntropy: Bool { get }
    
    // MARK: - Clear values
    
    func clearDeviceID()
    func deleteVault()
    func clearAppKey()
    func clearStoredMasterKey()
    func clearBiometryKey()
    func clearEncryptionReference()
    func clearStoredEntropy()
    
    func randomizeAppKey()

    // MARK: - WebDAV debug
    var writeDecryptedCopy: Bool { get }
    func setWriteDecryptedCopy(_ writeDecryptedCopy: Bool)
    
    func reboot()
}

final class ModifyStateModuleInteractor {
    private let debugInteractor: DebugInteracting
    
    init(debugInteractor: DebugInteracting) {
        self.debugInteractor = debugInteractor
    }
}

extension ModifyStateModuleInteractor: ModifyStateModuleInteracting {
    var hasDeviceID: Bool { debugInteractor.hasDeviceID }
    var hasSelectedVault: Bool { debugInteractor.hasSelectedVault }
    var hasAppKey: Bool { debugInteractor.hasAppKey }
    var hasStoredMasterKey: Bool { debugInteractor.hasStoredMasterKey }
    var hasBiometryKey: Bool { debugInteractor.hasBiometryKey }
    var hasEncryptionReference: Bool { debugInteractor.hasEncryptionReference }
    var hasStoredEntropy: Bool { debugInteractor.hasStoredEntropy }
        
    func clearDeviceID() {
        debugInteractor.clearDeviceID()
    }
    
    func deleteVault() {
        debugInteractor.deleteVault()
    }
    
    func clearAppKey() {
        debugInteractor.clearAppKey()
    }
    
    func clearStoredMasterKey() {
        debugInteractor.clearStoredMasterKey()
    }
    
    func clearBiometryKey() {
        debugInteractor.clearBiometryKey()
    }
    
    func clearEncryptionReference() {
        debugInteractor.clearEncryptionReference()
    }
    
    func clearStoredEntropy() {
        debugInteractor.clearStoredEntropy()
    }

    func reboot() {
        debugInteractor.reboot()
    }
    
    var writeDecryptedCopy: Bool {
        debugInteractor.writeDecryptedCopy
    }
    
    func setWriteDecryptedCopy(_ writeDecryptedCopy: Bool) {
        debugInteractor.setWriteDecryptedCopy(writeDecryptedCopy)
    }
    
    func randomizeAppKey() {
        debugInteractor.randomizeAppKey()
    }
}
