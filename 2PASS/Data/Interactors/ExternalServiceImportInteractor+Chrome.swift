// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import SwiftCSV

extension ExternalServiceImportInteractor {

    struct ChromeImporter {
        let context: ImportContext

        func `import`(_ content: Data) async throws(ExternalServiceImportError) -> [ItemData] {
            guard let csvString = String(data: content, encoding: .utf8) else {
                throw .wrongFormat
            }
            guard let vaultID = context.selectedVaultId else {
                throw .wrongFormat
            }
            var items: [ItemData] = []
            let protectionLevel = context.currentProtectionLevel

            do {
                let csv = try CSV<Enumerated>(string: csvString, delimiter: .comma)
                guard csv.header.containsAll(["name", "url", "username", "password", "note"]) else {
                    throw ExternalServiceImportError.wrongFormat
                }
                try csv.enumerateAsDict { dict in
                    guard dict.allValuesEmpty == false else { return }

                    let name = dict["name"].formattedName
                    let uris: [PasswordURI]? = {
                        guard let urlString = dict["url"]?.nilIfEmpty else { return nil }
                        let uri = PasswordURI(uri: urlString, match: .domain)
                        return [uri]
                    }()
                    let username = dict["username"]?.nilIfEmpty ?? dict["username2"]?.nilIfEmpty ?? dict["username3"]?.nilIfEmpty
                    let password: Data? = {
                        if let passwordString = dict["password"]?.nilIfEmpty,
                           let password = context.encryptSecureField(passwordString, for: protectionLevel) {
                            return password
                        }
                        return nil
                    }()
                    let notes = dict["note"]?.nilIfEmpty

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
            } catch let error as ExternalServiceImportError {
                throw error
            } catch {
                throw .wrongFormat
            }

            return items
        }
    }
}
