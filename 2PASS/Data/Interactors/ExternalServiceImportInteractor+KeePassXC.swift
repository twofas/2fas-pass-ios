// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import SwiftCSV

extension ExternalServiceImportInteractor {

    struct KeePassXCImporter {
        let context: ImportContext

        func `import`(_ content: Data) async throws(ExternalServiceImportError) -> ExternalServiceImportResult {
            guard let csvString = String(data: content, encoding: .utf8) else {
                throw .wrongFormat
            }
            guard let vaultID = context.selectedVaultId else {
                throw .wrongFormat
            }
            var passwords: [ItemData] = []
            var tagNameToId: [String: ItemTagID] = [:]
            var tagNames: [String] = []
            let protectionLevel = context.currentProtectionLevel

            do {
                let csv = try CSV<Enumerated>(string: csvString, delimiter: .comma)
                let requiredHeaders = [
                    "Group",
                    "Title",
                    "Username",
                    "Password",
                    "URL",
                    "Notes",
                    "Last Modified",
                    "Created"
                ]
                guard csv.header.containsAll(requiredHeaders) else {
                    throw ExternalServiceImportError.wrongFormat
                }
                let knownCSVColumns = Set(requiredHeaders).union(["Icon"])
                let dateFormatter = ISO8601DateFormatter()
                try csv.enumerateAsDict { dict in
                    guard dict.allValuesEmpty == false else { return }

                    let groupTag = groupTagName(from: dict["Group"])
                    if let groupTag, tagNameToId[groupTag] == nil {
                        let tagId = ItemTagID()
                        tagNameToId[groupTag] = tagId
                        tagNames.append(groupTag)
                    }
                    let tagIds: [ItemTagID]? = {
                        guard let groupTag, let tagId = tagNameToId[groupTag] else { return nil }
                        return [tagId]
                    }()

                    let name = dict["Title"].formattedName
                    let uris: [PasswordURI]? = {
                        guard let urlString = dict["URL"]?.nonBlankTrimmedOrNil else { return nil }
                        let uri = PasswordURI(uri: urlString, match: .domain)
                        return [uri]
                    }()
                    let username = dict["Username"]?.nonBlankTrimmedOrNil
                    let password: Data? = {
                        if let passwordString = dict["Password"]?.nonBlankTrimmedOrNil,
                           let password = context.encryptSecureField(passwordString, for: protectionLevel) {
                            return password
                        }
                        return nil
                    }()
                    let originalNotes = dict["Notes"]?.nonBlankTrimmedOrNil
                    let additionalInfo = context.formatDictionary(dict, excludingKeys: knownCSVColumns)
                    let notes = context.mergeNote(originalNotes, with: additionalInfo)

                    let creationDate = dict["Created"]?.nonBlankTrimmedOrNil.flatMap { dateFormatter.date(from: $0) }
                    let modificationDate = dict["Last Modified"]?.nonBlankTrimmedOrNil.flatMap { dateFormatter.date(from: $0) }

                    passwords.append(
                        .login(
                            .init(
                                id: .init(),
                                vaultId: vaultID,
                                metadata: .init(
                                    creationDate: creationDate ?? Date.importPasswordPlaceholder,
                                    modificationDate: modificationDate ?? Date.importPasswordPlaceholder,
                                    protectionLevel: protectionLevel,
                                    trashedStatus: .no,
                                    tagIds: tagIds
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
                            )
                        )
                    )
                }
            } catch let error as ExternalServiceImportError {
                throw error
            } catch {
                throw .wrongFormat
            }

            let tags: [ItemTagData] = tagNames.enumerated().compactMap { index, tagName -> ItemTagData? in
                guard let tagId = tagNameToId[tagName] else { return nil }
                return ItemTagData(
                    tagID: tagId,
                    vaultID: vaultID,
                    name: tagName,
                    color: .gray,
                    position: index,
                    modificationDate: Date()
                )
            }

            return ExternalServiceImportResult(items: passwords, tags: tags)
        }

        private func groupTagName(from group: String?) -> String? {
            guard let group = group?.nonBlankTrimmedOrNil else { return nil }
            let components = group
                .split(separator: "/")
                .map { String($0).trim() }
                .filter { !$0.isEmpty }
            guard !components.isEmpty else { return nil }
            if components.count == 1 {
                return components[0] == "Root" ? nil : components[0]
            }
            if components.first == "Root" {
                let remainder = components.dropFirst()
                return remainder.isEmpty ? nil : remainder.joined(separator: "/")
            }
            return components.joined(separator: "/")
        }
    }
}
