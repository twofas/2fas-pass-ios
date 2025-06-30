// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

@Observable
final class AppStatePresenter {
    struct Entry: Identifiable, Hashable {
        let id: UUID
        let name: String
        let isAvailable: Bool
        let value: String?
    }
    
    var entries: [Entry] = []
    
    private let interactor: AppStateModuleInteracting
    
    init(interactor: AppStateModuleInteracting) {
        self.interactor = interactor
    }
}

extension AppStatePresenter {
    func onAppear() {
        reload()
    }
    
    func onRefresh() {
        reload()
    }
}

private extension AppStatePresenter {
    func reload() {
        entries = [
            .init(
                id: .init(),
                name: "Device ID",
                isAvailable: interactor.hasDeviceID,
                value: interactor.deviceID?.uuidString
            ),
            .init(
                id: .init(),
                name: "Selected Vault",
                isAvailable: interactor.hasSelectedVault,
                value: interactor.selectedVaultID?.uuidString
            ),
            .init(
                id: .init(),
                name: "In memory storage",
                isAvailable: interactor.isInMemoryStorageActive,
                value: "-"
            ),
            .init(
                id: .init(),
                name: "Master Key (stored in Keychain, encrypted using Biometry Key)",
                isAvailable: interactor.hasStoredMasterKey,
                value: interactor.storedMasterKey?.hexEncodedString()
            ),
            .init(
                id: .init(),
                name: "Biometry Key",
                isAvailable: interactor.hasBiometryKey,
                value: "-"
            ),
            .init(
                id: .init(),
                name: "App Key",
                isAvailable: interactor.hasAppKey,
                value: "-"
            ),
            .init(
                id: .init(),
                name: "Seed",
                isAvailable: interactor.hasSeed,
                value: interactor.seed?.hexEncodedString()
            ),
            .init(
                id: .init(),
                name: "In memory Entropy",
                isAvailable: interactor.hasInMemoryEntropy,
                value: interactor.inMemoryEntropy?.hexEncodedString()
            ),
            .init(
                id: .init(),
                name: "Words",
                isAvailable: interactor.hasWords,
                value: interactor.words?.joined(separator: ", ")
            ),
            .init(
                id: .init(),
                name: "Salt",
                isAvailable: interactor.hasSalt,
                value: interactor.salt?.hexEncodedString()
            ),
            .init(
                id: .init(),
                name: "Master Password",
                isAvailable: interactor.hasMasterPassword,
                value: interactor.masterPassword
            ),
            .init(
                id: .init(),
                name: "In memory Master Key",
                isAvailable: interactor.hasInMemoryMasterKey,
                value: interactor.inMemoryMasterKey?.hexEncodedString()
            ),
            .init(
                id: .init(),
                name: "Encryption Reference",
                isAvailable: interactor.hasEncryptionReference,
                value: "-"
            ),
            .init(
                id: .init(),
                name: "Entropy (stored in Keychain, encrypted using App Key",
                isAvailable: interactor.hasStoredEntropy,
                value: interactor.storedEntropy?.hexEncodedString()
            ),
            .init(
                id: .init(),
                name: "Trusted Key",
                isAvailable: interactor.hasTrustedKey,
                value: interactor.trustedKey?.hexEncodedString()
            ),
            .init(
                id: .init(),
                name: "Secure Key",
                isAvailable: interactor.hasSecureKey,
                value: interactor.secureKey?.hexEncodedString()
            ),
            .init(
                id: .init(),
                name: "External Key",
                isAvailable: interactor.hasExternalKey,
                value: interactor.externalKey?.hexEncodedString()
            ),
        ]
    }
}
