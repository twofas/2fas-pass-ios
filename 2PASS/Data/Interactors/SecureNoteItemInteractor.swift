// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

public protocol SecureNoteItemInteracting: AnyObject {
    func createSecureNote(
        id: ItemID,
        metadata: ItemMetadata,
        name: String,
        text: String?
    ) throws(ItemsInteractorSaveError)

    func updateSecureNote(
        id: ItemID,
        metadata: ItemMetadata,
        name: String,
        text: String?
    ) throws(ItemsInteractorSaveError)
}

final class SecureNoteItemInteractor {
    private let itemsInteractor: ItemsInteracting

    init(itemsInteractor: ItemsInteracting) {
        self.itemsInteractor = itemsInteractor
    }
}

extension SecureNoteItemInteractor: SecureNoteItemInteracting {

    func createSecureNote(id: ItemID, metadata: ItemMetadata, name: String, text: String?) throws(ItemsInteractorSaveError) {
        let secureNoteItem = try makeSecureNote(id: id, metadata: metadata, name: name, text: text)
        try itemsInteractor.createItem(.secureNote(secureNoteItem))
    }

    func updateSecureNote(id: ItemID, metadata: ItemMetadata, name: String, text: String?) throws(ItemsInteractorSaveError) {
        let secureNoteItem = try makeSecureNote(id: id, metadata: metadata, name: name, text: text)
        try itemsInteractor.updateItem(.secureNote(secureNoteItem))
    }
}

private extension SecureNoteItemInteractor {

    func makeSecureNote(id: ItemID, metadata: ItemMetadata, name: String, text: String?) throws(ItemsInteractorSaveError) -> SecureNoteItemData {
        var encryptedText: Data?
        if let text = text?.trim(), !text.isEmpty {
            guard let encrypted = itemsInteractor.encrypt(text, isSecureField: true, protectionLevel: metadata.protectionLevel) else {
                Log(
                    "SecureNoteItemInteractor: Create secure note. Can't encrypt text",
                    module: .interactor,
                    severity: .error
                )
                throw .encryptionError
            }
            encryptedText = encrypted
        }

        return .init(
            id: id,
            metadata: metadata,
            name: name,
            content: .init(
                name: name,
                text: encryptedText
            )
        )
    }
}
