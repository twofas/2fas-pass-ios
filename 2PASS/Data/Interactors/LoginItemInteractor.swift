// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

public protocol LoginItemInteracting: AnyObject {
    func createLogin(
        id: ItemID,
        metadata: ItemMetadata,
        name: String?,
        username: String?,
        password: String?,
        notes: String?,
        iconType: PasswordIconType,
        uris: [PasswordURI]?
    ) throws(ItemsInteractorSaveError)

    func updateLogin(
        id: ItemID,
        metadata: ItemMetadata,
        name: String?,
        username: String?,
        password: String?,
        notes: String?,
        iconType: PasswordIconType,
        uris: [PasswordURI]?
    ) throws(ItemsInteractorSaveError)
}

final class LoginItemInteractor {
    private let itemsInteractor: ItemsInteracting
    private let mainRepository: MainRepository

    init(itemsInteractor: ItemsInteracting, mainRepository: MainRepository) {
        self.itemsInteractor = itemsInteractor
        self.mainRepository = mainRepository
    }
}

extension LoginItemInteractor: LoginItemInteracting {

    func createLogin(id: ItemID, metadata: ItemMetadata, name: String?, username: String?, password: String?, notes: String?, iconType: PasswordIconType, uris: [PasswordURI]?) throws(ItemsInteractorSaveError) {
        let vaultId = try selectedVaultId
        let loginItem = try makeLogin(id: id, vaultId: vaultId, metadata: metadata, name: name, username: username, password: password, notes: notes, iconType: iconType, uris: uris)
        try itemsInteractor.createItem(.login(loginItem))
    }

    func updateLogin(id: ItemID, metadata: ItemMetadata, name: String?, username: String?, password: String?, notes: String?, iconType: PasswordIconType, uris: [PasswordURI]?) throws(ItemsInteractorSaveError) {
        let vaultId = try selectedVaultId
        let loginItem = try makeLogin(id: id, vaultId: vaultId, metadata: metadata, name: name, username: username, password: password, notes: notes, iconType: iconType, uris: uris)
        try itemsInteractor.updateItem(.login(loginItem))
    }
}

private extension LoginItemInteractor {

    var selectedVaultId: VaultID {
        get throws(ItemsInteractorSaveError) {
            guard let vaultId = mainRepository.selectedVault?.vaultID else {
                throw .noVault
            }
            return vaultId
        }
    }

    func makeLogin(id: ItemID, vaultId: VaultID, metadata: ItemMetadata, name: String?, username: String?, password: String?, notes: String?, iconType: PasswordIconType, uris: [PasswordURI]?) throws(ItemsInteractorSaveError) -> LoginItemData {
        var encryptedPassword: Data?
        if let password = password?.trim(), !password.isEmpty {
            guard let encrypted = itemsInteractor.encrypt(password, isSecureField: true, protectionLevel: metadata.protectionLevel) else {
                Log(
                    "LoginItemInteractor: Create login. Can't encrypt password",
                    module: .interactor,
                    severity: .error
                )
                throw .encryptionError
            }
            encryptedPassword = encrypted
        }

        return .init(
            id: id,
            vaultId: vaultId,
            metadata: metadata,
            name: name,
            content: .init(
                name: name?.nilIfEmpty,
                username: username?.nilIfEmpty,
                password: encryptedPassword,
                notes: notes,
                iconType: iconType,
                uris: uris
            )
        )
    }
}
