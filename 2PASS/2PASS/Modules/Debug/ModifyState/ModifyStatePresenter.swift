// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

@Observable
final class ModifyStatePresenter {
    struct Entry: Hashable, Identifiable {
        enum Element {
            case deviceID
            case vault
            case appKey
            case storedMasterKey
            case biometryKey
            case encryptionReference
            case storedEntropy
            
            var title: String {
                switch self {
                case .deviceID: "DeviceID"
                case .vault: "Vault"
                case .appKey: "App Key"
                case .storedMasterKey: "Stored Master Key"
                case .biometryKey: "Biometry Key"
                case .encryptionReference: "Encryption Reference"
                case .storedEntropy: "Stored Entropy"
                }
            }
        }
        let id: Element
        let isEnabled: Bool
        var isOn = false
    }
    
    var list: [Entry] = [] {
        didSet {
            updateRebootButtonState()
        }
    }
    var rebootButtonEnabled = false
    var writeDecryptedCopy = false {
        didSet {
            interactor.setWriteDecryptedCopy(writeDecryptedCopy)
        }
    }
    
    private let interactor: ModifyStateModuleInteracting
    
    init(interactor: ModifyStateModuleInteracting) {
        self.interactor = interactor
    }
    
    func onAppear() {
        list = [
            .init(id: .deviceID, isEnabled: interactor.hasDeviceID),
            .init(id: .vault, isEnabled: interactor.hasSelectedVault),
            .init(id: .appKey, isEnabled: interactor.hasAppKey),
            .init(id: .storedMasterKey, isEnabled: interactor.hasStoredMasterKey),
            .init(id: .biometryKey, isEnabled: interactor.hasBiometryKey),
            .init(id: .encryptionReference, isEnabled: interactor.hasEncryptionReference),
            .init(id: .storedEntropy, isEnabled: interactor.hasStoredEntropy)
        ]
        writeDecryptedCopy = interactor.writeDecryptedCopy
    }
    
    func updateRebootButtonState() {
        rebootButtonEnabled = list.reduce(into: false, { partialResult, entry in
            partialResult = partialResult || entry.isOn
        })
    }
    
    func onReboot() {
        for entry in list {
            guard entry.isOn else { continue }
            switch entry.id {
            case .deviceID: interactor.clearDeviceID()
            case .vault: interactor.deleteVault()
            case .appKey: interactor.clearAppKey()
            case .storedMasterKey: interactor.clearStoredMasterKey()
            case .biometryKey: interactor.clearBiometryKey()
            case .encryptionReference: interactor.clearEncryptionReference()
            case .storedEntropy: interactor.clearStoredEntropy()
            }
        }
        interactor.reboot()
    }
}
