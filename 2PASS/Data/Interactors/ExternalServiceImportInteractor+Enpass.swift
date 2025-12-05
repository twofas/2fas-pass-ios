// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

extension ExternalServiceImportInteractor {

    struct EnpassImporter {
        let context: ImportContext

        func `import`(_ content: Data) async throws(ExternalServiceImportError) -> [ItemData] {
            guard let parsedJSON = try? context.jsonDecoder.decode(Enpass.self, from: content) else {
                throw .wrongFormat
            }
            guard let vaultID = context.selectedVaultId else {
                throw .wrongFormat
            }
            var items: [ItemData] = []
            let protectionLevel = context.currentProtectionLevel

            parsedJSON.items?.forEach { item in
                guard item.trashed != 1 else { return }

                let name = item.title.formattedName
                let notes = item.note?.nilIfEmpty

                var username: String?
                var email: String?
                var password: Data?
                var urlString: String?

                item.fields?.forEach { field in
                    guard field.deleted != 1 else { return }

                    switch field.type {
                    case "username":
                        username = field.value?.nilIfEmpty
                    case "email":
                        email = field.value?.nilIfEmpty
                    case "password":
                        if let passwordString = field.value?.nilIfEmpty {
                            password = context.encryptSecureField(passwordString, for: protectionLevel)
                        }
                    case "url":
                        urlString = field.value?.nilIfEmpty
                    default:
                        break
                    }
                }
                
                username = username ?? email

                let uris: [PasswordURI]? = {
                    guard let urlString else { return nil }
                    let uri = PasswordURI(uri: urlString, match: .domain)
                    return [uri]
                }()

                items.append(
                    .login(.init(
                        id: .init(),
                        vaultId: vaultID,
                        metadata: .init(
                            creationDate: Date.importPasswordPlaceholder,
                            modificationDate: Date.importPasswordPlaceholder,
                            protectionLevel: protectionLevel,
                            trashedStatus: .no,
                            tagIds: nil
                        ),
                        name: name,
                        content: .init(
                            name: name,
                            username: username,
                            password: password,
                            notes: notes,
                            iconType: context.makeIconType(uri: uris?.first?.uri),
                            uris: uris
                        )
                    ))
                )
            }

            return items
        }
    }
}

// MARK: - Enpass Format Models

private struct Enpass: Decodable {
    struct Item: Decodable {
        struct Field: Decodable {
            let label: String?
            let type: String?
            let value: String?
            let sensitive: Int?
            let deleted: Int?
        }

        let title: String?
        let note: String?
        let category: String?
        let fields: [Field]?
        let trashed: Int?
    }

    let items: [Item]?
}
