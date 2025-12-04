// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

extension ExternalServiceImportInteractor {

    struct BitWardenImporter {
        let context: ImportContext

        func `import`(_ content: Data) async throws(ExternalServiceImportError) -> [ItemData] {
            guard let parsedJSON = try? context.jsonDecoder.decode(BitWarden.self, from: content),
                  parsedJSON.encrypted == false
            else {
                throw .wrongFormat
            }
            guard let vaultID = context.selectedVaultId else {
                throw .wrongFormat
            }
            var items: [ItemData] = []
            let protectionLevel = context.currentProtectionLevel

            parsedJSON.items?.forEach { item in
                let name = item.name.formattedName
                let notes = item.notes
                let username = item.login?.username
                let password: Data? = {
                    if let passwordString = item.login?.password?.nilIfEmpty,
                       let password = context.encryptSecureField(passwordString, for: protectionLevel) {
                        return password
                    }
                    return nil
                }()
                let uris: [PasswordURI]? = { () -> [PasswordURI]? in
                    guard let list = item.login?.uris else {
                        return nil
                    }
                    let urisList: [PasswordURI] = list.compactMap { uriEntry in
                        guard let uri = uriEntry.uri, !uri.isEmpty else {
                            return nil
                        }
                        return PasswordURI(uri: uri, match: uriEntry.matchValue)
                    }
                    guard !urisList.isEmpty else {
                        return nil
                    }
                    return urisList
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

// MARK: - BitWarden Format Models

private struct BitWarden: Decodable {
    struct Item: Decodable {
        struct Login: Decodable {
            struct URI: Decodable {
                let uri: String?
                let match: Int?

                var matchValue: PasswordURI.Match {
                    switch match {
                    case 0: .domain
                    case 1: .host
                    case 2: .startsWith
                    case 3: .exact
                    default: .domain
                    }
                }
            }

            let username: String?
            let password: String?
            let uris: [URI]?
        }

        let name: String?
        let notes: String?
        let login: Login?
    }
    let encrypted: Bool
    let items: [Item]?
}
