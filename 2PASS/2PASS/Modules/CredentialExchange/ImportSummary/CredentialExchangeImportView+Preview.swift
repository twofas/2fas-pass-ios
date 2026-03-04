// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import AuthenticationServices
import Common
import Data
import SwiftUI

@available(iOS 26.0, *)
private final class PreviewInteractor: CredentialExchangeImportModuleInteracting {
    func convertCredentials(_ data: ASExportedCredentialData) throws(CredentialExchangeImportError) -> ExternalServiceImportResult {
        let vaultID = VaultID()
        let workTagID = ItemTagID()
        let personalTagID = ItemTagID()
        let now = Date()

        let tags: [ItemTagData] = [
            ItemTagData(
                tagID: workTagID,
                vaultID: vaultID,
                name: "Work",
                color: .indigo,
                position: 0,
                modificationDate: now
            ),
            ItemTagData(
                tagID: personalTagID,
                vaultID: vaultID,
                name: "Personal",
                color: .green,
                position: 1,
                modificationDate: now
            )
        ]

        let loginItem: ItemData = .login(.init(
            id: ItemID(),
            vaultId: vaultID,
            metadata: .init(
                creationDate: now,
                modificationDate: now,
                protectionLevel: .normal,
                trashedStatus: .no,
                tagIds: [workTagID]
            ),
            name: "Example Login",
            content: .init(
                name: "Example Login",
                username: "john@example.com",
                password: nil,
                notes: "Work account",
                iconType: .domainIcon("example.com"),
                uris: [PasswordURI(uri: "https://example.com", match: .domain)]
            )
        ))

        let paymentCardItem: ItemData = .paymentCard(.init(
            id: ItemID(),
            vaultId: vaultID,
            metadata: .init(
                creationDate: now,
                modificationDate: now,
                protectionLevel: .normal,
                trashedStatus: .no,
                tagIds: [personalTagID]
            ),
            name: "Example Card",
            content: .init(
                name: "Example Card",
                cardHolder: "John Doe",
                cardIssuer: "Visa",
                cardNumber: nil,
                cardNumberMask: "**** 4242",
                expirationDate: nil,
                securityCode: nil,
                notes: "Personal card"
            )
        ))

        let secureNoteItem: ItemData = .secureNote(.init(
            id: ItemID(),
            vaultId: vaultID,
            metadata: .init(
                creationDate: now,
                modificationDate: now,
                protectionLevel: .normal,
                trashedStatus: .no,
                tagIds: nil
            ),
            name: "Example Secure Note",
            content: .init(
                name: "Example Secure Note",
                text: "This is an imported secure note.".data(using: .utf8),
                additionalInfo: nil
            )
        ))

        let convertedSecureNoteItem: ItemData = .secureNote(.init(
            id: ItemID(),
            vaultId: vaultID,
            metadata: .init(
                creationDate: now,
                modificationDate: now,
                protectionLevel: .normal,
                trashedStatus: .no,
                tagIds: nil
            ),
            name: "Example Imported Item (Address)",
            content: .init(
                name: "Example Imported Item (Address)",
                text: "Street Address: Infinite Loop 1".data(using: .utf8),
                additionalInfo: nil
            )
        ))

        return ExternalServiceImportResult(
            items: [loginItem, paymentCardItem, secureNoteItem, convertedSecureNoteItem],
            tags: tags,
            itemsConvertedToSecureNotes: 1
        )
    }
}

@available(iOS 26.0, *)
#Preview {
    CredentialExchangeImportView(
        presenter: {
            let presenter = CredentialExchangeImportPresenter(
                data: .init(
                    accounts: [],
                    formatVersion: .v1,
                    exporterRelyingPartyIdentifier: "apple.com",
                    exporterDisplayName: "Apple Passwords",
                    timestamp: Date()
                ),
                interactor: PreviewInteractor(),
                onClose: {}
            )
            return presenter
        }()
    )
}
