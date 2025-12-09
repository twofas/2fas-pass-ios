// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

extension ExternalServiceImportInteractor {

    struct KeeperImporter {
        let context: ImportContext

        func `import`(_ content: Data) async throws(ExternalServiceImportError) -> [ItemData] {
            guard let parsedJSON = try? context.jsonDecoder.decode(Keeper.self, from: content) else {
                throw .wrongFormat
            }
            guard let vaultID = context.selectedVaultId else {
                throw .wrongFormat
            }
            var items: [ItemData] = []
            let protectionLevel = context.currentProtectionLevel

            parsedJSON.records?.forEach { record in
                // Import login and encryptedNotes type records
                guard record.type == "login" || record.type == "encryptedNotes" else { return }

                let name = record.title.formattedName
                let notes = record.notes?.nilIfEmpty
                let username = record.login?.nilIfEmpty
                let password: Data? = {
                    if let passwordString = record.password?.nilIfEmpty {
                        return context.encryptSecureField(passwordString, for: protectionLevel)
                    }
                    return nil
                }()

                let uris: [PasswordURI]? = {
                    guard let urlString = record.loginUrl?.nilIfEmpty else { return nil }
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

// MARK: - Keeper Format Models

private struct Keeper: Decodable {
    struct Record: Decodable {
        let title: String?
        let notes: String?
        let type: String?
        let login: String?
        let password: String?
        let loginUrl: String?

        enum CodingKeys: String, CodingKey {
            case title
            case notes
            case type = "$type"
            case login
            case password
            case loginUrl = "login_url"
        }
    }

    let records: [Record]?
}
