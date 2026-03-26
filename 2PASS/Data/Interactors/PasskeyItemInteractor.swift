// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public protocol PasskeyItemInteracting: AnyObject {
    func createPasskey(
        id: ItemID,
        metadata: ItemMetadata,
        name: String?,
        credentialID: Data,
        rpID: String,
        username: String,
        userHandle: Data,
        privateKey: Data
    ) throws(ItemsInteractorSaveError)

    func updatePasskey(
        id: ItemID,
        metadata: ItemMetadata,
        name: String?,
        credentialID: Data,
        rpID: String,
        username: String,
        userHandle: Data,
        privateKey: Data
    ) throws(ItemsInteractorSaveError)
}

final class PasskeyItemInteractor {
    private let itemsInteractor: ItemsInteracting
    private let mainRepository: MainRepository

    init(itemsInteractor: ItemsInteracting, mainRepository: MainRepository) {
        self.itemsInteractor = itemsInteractor
        self.mainRepository = mainRepository
    }
}

extension PasskeyItemInteractor: PasskeyItemInteracting {

    func createPasskey(
        id: ItemID,
        metadata: ItemMetadata,
        name: String?,
        credentialID: Data,
        rpID: String,
        username: String,
        userHandle: Data,
        privateKey: Data
    ) throws(ItemsInteractorSaveError) {
        let vaultId = try selectedVaultId
        let passkeyItem = try makePasskey(
            id: id, vaultId: vaultId, metadata: metadata, name: name,
            credentialID: credentialID, rpID: rpID, username: username,
            userHandle: userHandle, privateKey: privateKey
        )
        try itemsInteractor.createItem(.passkey(passkeyItem))
    }

    func updatePasskey(
        id: ItemID,
        metadata: ItemMetadata,
        name: String?,
        credentialID: Data,
        rpID: String,
        username: String,
        userHandle: Data,
        privateKey: Data
    ) throws(ItemsInteractorSaveError) {
        let vaultId = try selectedVaultId
        let passkeyItem = try makePasskey(
            id: id, vaultId: vaultId, metadata: metadata, name: name,
            credentialID: credentialID, rpID: rpID, username: username,
            userHandle: userHandle, privateKey: privateKey
        )
        try itemsInteractor.updateItem(.passkey(passkeyItem))
    }
}

private extension PasskeyItemInteractor {

    var selectedVaultId: VaultID {
        get throws(ItemsInteractorSaveError) {
            guard let vaultId = mainRepository.selectedVault?.vaultID else {
                throw .noVault
            }
            return vaultId
        }
    }

    func makePasskey(
        id: ItemID,
        vaultId: VaultID,
        metadata: ItemMetadata,
        name: String?,
        credentialID: Data,
        rpID: String,
        username: String,
        userHandle: Data,
        privateKey: Data
    ) throws(ItemsInteractorSaveError) -> PasskeyItemData {
        guard let encryptedPrivateKey = itemsInteractor.encryptData(
            privateKey,
            isSecureField: true,
            protectionLevel: metadata.protectionLevel
        ) else {
            Log(
                "PasskeyItemInteractor: Can't encrypt passkey private key",
                module: .interactor,
                severity: .error
            )
            throw .encryptionError
        }

        return .init(
            id: id,
            vaultId: vaultId,
            metadata: metadata,
            name: name,
            content: .init(
                name: name,
                credentialId: credentialID,
                rpId: rpID,
                username: username,
                userHandle: userHandle,
                privateKey: encryptedPrivateKey
            )
        )
    }
}
