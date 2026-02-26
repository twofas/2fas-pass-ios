// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

public protocol WiFiItemInteracting: AnyObject {
    func createWiFi(
        id: ItemID,
        metadata: ItemMetadata,
        name: String,
        ssid: String?,
        password: String?,
        notes: String?,
        securityType: WiFiContent.SecurityType,
        hidden: Bool
    ) throws(ItemsInteractorSaveError)

    func updateWiFi(
        id: ItemID,
        metadata: ItemMetadata,
        name: String,
        ssid: String?,
        password: String?,
        notes: String?,
        securityType: WiFiContent.SecurityType,
        hidden: Bool
    ) throws(ItemsInteractorSaveError)
}

final class WiFiItemInteractor {
    private let itemsInteractor: ItemsInteracting
    private let mainRepository: MainRepository

    init(itemsInteractor: ItemsInteracting, mainRepository: MainRepository) {
        self.itemsInteractor = itemsInteractor
        self.mainRepository = mainRepository
    }
}

extension WiFiItemInteractor: WiFiItemInteracting {
    func createWiFi(
        id: ItemID,
        metadata: ItemMetadata,
        name: String,
        ssid: String?,
        password: String?,
        notes: String?,
        securityType: WiFiContent.SecurityType,
        hidden: Bool
    ) throws(ItemsInteractorSaveError) {
        let vaultId = try selectedVaultId
        let wifiItem = try makeWiFi(
            id: id,
            vaultId: vaultId,
            metadata: metadata,
            name: name,
            ssid: ssid,
            password: password,
            notes: notes,
            securityType: securityType,
            hidden: hidden
        )
        try itemsInteractor.createItem(.wifi(wifiItem))
    }

    func updateWiFi(
        id: ItemID,
        metadata: ItemMetadata,
        name: String,
        ssid: String?,
        password: String?,
        notes: String?,
        securityType: WiFiContent.SecurityType,
        hidden: Bool
    ) throws(ItemsInteractorSaveError) {
        let vaultId = try selectedVaultId
        let wifiItem = try makeWiFi(
            id: id,
            vaultId: vaultId,
            metadata: metadata,
            name: name,
            ssid: ssid,
            password: password,
            notes: notes,
            securityType: securityType,
            hidden: hidden
        )
        try itemsInteractor.updateItem(.wifi(wifiItem))
    }
}

private extension WiFiItemInteractor {
    var selectedVaultId: VaultID {
        get throws(ItemsInteractorSaveError) {
            guard let vaultId = mainRepository.selectedVault?.vaultID else {
                throw .noVault
            }
            return vaultId
        }
    }

    func makeWiFi(
        id: ItemID,
        vaultId: VaultID,
        metadata: ItemMetadata,
        name: String,
        ssid: String?,
        password: String?,
        notes: String?,
        securityType: WiFiContent.SecurityType,
        hidden: Bool
    ) throws(ItemsInteractorSaveError) -> WiFiItemData {
        let encryptedPassword: Data?

        if let passwordTrimmed = password?.trim(), passwordTrimmed.isEmpty == false {
            guard let encrypted = itemsInteractor.encrypt(
                passwordTrimmed,
                isSecureField: true,
                protectionLevel: metadata.protectionLevel
            ) else {
                Log("WiFiItemInteractor: Can't encrypt password", module: .interactor, severity: .error)
                throw .encryptionError
            }
            encryptedPassword = encrypted
        } else {
            encryptedPassword = nil
        }

        return .init(
            id: id,
            vaultId: vaultId,
            metadata: metadata,
            name: name,
            content: .init(
                name: name,
                ssid: ssid?.nonBlankTrimmedOrNil,
                password: encryptedPassword,
                notes: notes?.nonBlankTrimmedOrNil,
                securityType: securityType,
                hidden: hidden
            )
        )
    }
}
