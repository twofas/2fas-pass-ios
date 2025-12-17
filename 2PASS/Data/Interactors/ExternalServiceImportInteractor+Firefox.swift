// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import SwiftCSV

extension ExternalServiceImportInteractor {

    struct FirefoxImporter {
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
                guard csv.header.containsAll(["url", "username", "password", "httpRealm", "formActionOrigin", "guid", "timeCreated", "timeLastUsed", "timePasswordChanged"]) else {
                    throw ExternalServiceImportError.wrongFormat
                }

                let excludingKeys: Set<String> = [
                    "url", "username", "password",
                    "timeCreated", "timePasswordChanged", "guid", "timeLastUsed"
                ]

                try csv.enumerateAsDict { dict in
                    guard dict.allValuesEmpty == false else { return }

                    let name = dict["url"].formattedName
                    let uris: [PasswordURI]? = {
                        guard let urlString = dict["url"]?.nilIfEmpty else { return nil }
                        let uri = PasswordURI(uri: urlString, match: .domain)
                        return [uri]
                    }()
                    let username = dict["username"]?.nilIfEmpty
                    let password: Data? = {
                        if let passwordString = dict["password"]?.nilIfEmpty,
                           let password = context.encryptSecureField(passwordString, for: protectionLevel) {
                            return password
                        }
                        return nil
                    }()
                    let timeCreated = dict["timeCreated"]?.nilIfEmpty
                    let timePasswordChanged = dict["timePasswordChanged"]?.nilIfEmpty
                    let timeLastUsed: String? = {
                        guard let timestampString = dict["timeLastUsed"]?.nilIfEmpty,
                              let timestamp = Int(timestampString) else { return nil }
                        let date = Date(exportTimestamp: timestamp)
                        return date.formatted(date: .abbreviated, time: .shortened)
                    }()

                    var additionalFields: [String] = []
                    if let otherFields = context.formatDictionary(dict, excludingKeys: excludingKeys) {
                        additionalFields.append(otherFields)
                    }
                    if let timeLastUsed {
                        additionalFields.append("Time Last Used: \(timeLastUsed)")
                    }
                    let additionalInfo = additionalFields.isEmpty ? nil : additionalFields.joined(separator: "\n")

                    items.append(
                        .login(.init(
                            id: .init(),
                            vaultId: vaultID,
                            metadata: .init(
                                creationDate: timeCreated.flatMap { Int($0) }.map { Date(exportTimestamp: $0) } ?? Date.importPasswordPlaceholder,
                                modificationDate: timePasswordChanged.flatMap { Int($0) }.map { Date(exportTimestamp: $0) } ?? Date.importPasswordPlaceholder,
                                protectionLevel: protectionLevel,
                                trashedStatus: .no,
                                tagIds: nil
                            ),
                            name: name,
                            content: .init(
                                name: name,
                                username: username,
                                password: password,
                                notes: additionalInfo,
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
