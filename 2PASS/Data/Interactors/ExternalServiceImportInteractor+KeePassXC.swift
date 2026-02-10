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
            do {
                return try await importXML(content)
            } catch {
                return try await importCSV(content)
            }
        }

        private func importCSV(_ content: Data) async throws(ExternalServiceImportError) -> ExternalServiceImportResult {
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
                    color: .unknown(nil),
                    position: index,
                    modificationDate: Date()
                )
            }

            return ExternalServiceImportResult(items: passwords, tags: tags)
        }

        private func importXML(_ content: Data) async throws(ExternalServiceImportError) -> ExternalServiceImportResult {
            guard let vaultID = context.selectedVaultId else {
                throw .wrongFormat
            }

            let parser = KeePassXMLParser(source: .keePassXC)

            guard let entries = try? parser.parse(content) else {
                throw .wrongFormat
            }

            let protectionLevel = context.currentProtectionLevel
            var items: [ItemData] = []

            var tagNameToId: [String: ItemTagID] = [:]
            var tagNames: [String] = []

            for entry in entries {
                let entryTagNames = collectTagNames(from: entry)
                registerTags(entryTagNames, tagNameToId: &tagNameToId, tagNames: &tagNames)
                let tagIds = resolveTagIds(from: entryTagNames, tagNameToId: tagNameToId)

                let name = entry.fields["Title"].formattedName
                let username = entry.fields["UserName"]?.nonBlankTrimmedOrNil
                let password: Data? = {
                    if let passwordString = entry.fields["Password"]?.nonBlankTrimmedOrNil,
                       let encrypted = context.encryptSecureField(passwordString, for: protectionLevel) {
                        return encrypted
                    }
                    return nil
                }()
                let uris: [PasswordURI]? = {
                    guard let urlString = entry.fields["URL"]?.nonBlankTrimmedOrNil else { return nil }
                    return [PasswordURI(uri: urlString, match: .domain)]
                }()

                let knownKeys: Set<String> = ["Title", "UserName", "Password", "URL", "Notes"]
                let originalNotes = entry.fields["Notes"]?.nonBlankTrimmedOrNil
                let additionalInfo = context.formatDictionary(entry.fields, excludingKeys: knownKeys)
                let notes = context.mergeNote(originalNotes, with: additionalInfo)

                items.append(
                    .login(
                        .init(
                            id: .init(),
                            vaultId: vaultID,
                            metadata: .init(
                                creationDate: entry.creationDate ?? Date.importPasswordPlaceholder,
                                modificationDate: entry.modificationDate ?? Date.importPasswordPlaceholder,
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

            let tags: [ItemTagData] = tagNames.enumerated().compactMap { index, tagName -> ItemTagData? in
                guard let tagId = tagNameToId[tagName] else { return nil }
                return ItemTagData(
                    tagID: tagId,
                    vaultID: vaultID,
                    name: tagName,
                    color: .unknown(nil),
                    position: index,
                    modificationDate: Date()
                )
            }

            return ExternalServiceImportResult(items: items, tags: tags)
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

        private func collectTagNames(from entry: KeePassXMLEntry) -> [String] {
            var tagCandidates: [String] = []
            if let groupTag = groupTagName(from: entry.groupPath) {
                tagCandidates.append(groupTag)
            }
            tagCandidates.append(contentsOf: entry.tags)

            var seen = Set<String>()
            var result: [String] = []
            for tag in tagCandidates {
                guard let trimmed = tag.nonBlankTrimmedOrNil, !seen.contains(trimmed) else { continue }
                seen.insert(trimmed)
                result.append(trimmed)
            }
            return result
        }

        private func groupTagName(from path: [String]) -> String? {
            let trimmedPath = path.compactMap { $0.nonBlankTrimmedOrNil }
            guard trimmedPath.count > 1 else { return nil }
            return trimmedPath.dropFirst().joined(separator: "/")
        }

        private func registerTags(
            _ tags: [String],
            tagNameToId: inout [String: ItemTagID],
            tagNames: inout [String]
        ) {
            for tagName in tags {
                if tagNameToId[tagName] == nil {
                    let tagId = ItemTagID()
                    tagNameToId[tagName] = tagId
                    tagNames.append(tagName)
                }
            }
        }

        private func resolveTagIds(from tags: [String], tagNameToId: [String: ItemTagID]) -> [ItemTagID]? {
            let tagIds = tags.compactMap { tagNameToId[$0] }
            return tagIds.isEmpty ? nil : tagIds
        }
    }
}
