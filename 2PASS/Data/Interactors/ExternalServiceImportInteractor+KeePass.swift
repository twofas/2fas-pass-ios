// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import SwiftCSV

extension ExternalServiceImportInteractor {

    struct KeePassImporter {
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
            let protectionLevel = context.currentProtectionLevel

            do {
                let csv = try CSV<Enumerated>(string: csvString, delimiter: .comma)
                guard csv.header.containsAll(["Account", "Login Name", "Password", "Web Site", "Comments"]) else {
                    throw ExternalServiceImportError.wrongFormat
                }
                try csv.enumerateAsDict { dict in
                    guard dict.allValuesEmpty == false else { return }

                    let name = dict["Account"].formattedName
                    let uris: [PasswordURI]? = {
                        guard let urlString = dict["Web Site"]?.nonBlankTrimmedOrNil else { return nil }
                        let uri = PasswordURI(uri: urlString, match: .domain)
                        return [uri]
                    }()
                    let username = dict["Login Name"]?.nonBlankTrimmedOrNil
                    let password: Data? = {
                        if let passwordString = dict["Password"]?.nonBlankTrimmedOrNil,
                           let password = context.encryptSecureField(passwordString, for: protectionLevel) {
                            return password
                        }
                        return nil
                    }()

                    let knownCSVColumns: Set<String> = [
                        "Account", "Login Name", "Password", "Web Site", "Comments"
                    ]
                    let originalNotes = dict["Comments"]?.nonBlankTrimmedOrNil
                    let csvAdditionalInfo = context.formatDictionary(dict, excludingKeys: knownCSVColumns)
                    let notes = context.mergeNote(originalNotes, with: csvAdditionalInfo)

                    passwords.append(
                        .login(
                            .init(
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
                            )
                        )
                    )
                }
            } catch let error as ExternalServiceImportError {
                throw error
            } catch {
                throw .wrongFormat
            }

            return ExternalServiceImportResult(items: passwords)
        }

        private func importXML(_ content: Data) async throws(ExternalServiceImportError) -> ExternalServiceImportResult {
            guard let vaultID = context.selectedVaultId else {
                throw .wrongFormat
            }

            let parser = KeePassXMLParser()
            
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
                    color: .gray,
                    position: index,
                    modificationDate: Date()
                )
            }

            return ExternalServiceImportResult(items: items, tags: tags)
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

private struct KeePassXMLEntry {
    var fields: [String: String]
    var tags: [String]
    var groupPath: [String]
    var creationDate: Date?
    var modificationDate: Date?
}

private final class KeePassXMLParser: NSObject, XMLParserDelegate {
    private var entries: [KeePassXMLEntry] = []
    private var currentEntry: KeePassXMLEntry?
    private var currentStringKey: String?
    private var currentText = ""
    private var elementStack: [String] = []
    private var groupStack: [String] = []
    private var isInHistory = false
    private var skippingEntryDepth: Int?
    private let dateFormatter = ISO8601DateFormatter()
    private var isKeePassFile = false

    func parse(_ data: Data) throws(ExternalServiceImportError) -> [KeePassXMLEntry] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse(), isKeePassFile else {
            throw .wrongFormat
        }
        return entries
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        elementStack.append(elementName)
        currentText = ""

        if elementStack.count == 1, elementName == "KeePassFile" {
            isKeePassFile = true
        }

        switch elementName {
        case "Group":
            groupStack.append("")
        case "History":
            isInHistory = true
        case "Entry":
            if isInHistory {
                skippingEntryDepth = elementStack.count
            } else {
                let groupPath = groupStack.compactMap { $0.nonBlankTrimmedOrNil }
                currentEntry = KeePassXMLEntry(
                    fields: [:],
                    tags: [],
                    groupPath: groupPath,
                    creationDate: nil,
                    modificationDate: nil
                )
            }
        case "String":
            if currentEntry != nil && skippingEntryDepth == nil {
                currentStringKey = nil
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        defer {
            elementStack.removeLast()
        }

        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if let skipDepth = skippingEntryDepth {
            if elementName == "Entry", elementStack.count == skipDepth {
                skippingEntryDepth = nil
            }
            return
        }

        switch elementName {
        case "Name":
            if elementStack.count >= 2,
               elementStack[elementStack.count - 2] == "Group",
               currentEntry == nil,
               !groupStack.isEmpty {
                groupStack[groupStack.count - 1] = text
            }
        case "Key":
            if currentEntry != nil {
                currentStringKey = text
            }
        case "Value":
            if var entry = currentEntry, let key = currentStringKey {
                entry.fields[key] = text
                currentEntry = entry
            }
        case "Tags":
            if var entry = currentEntry {
                let tags = text
                    .split(separator: ";")
                    .map { String($0).trim() }
                    .filter { !$0.isEmpty }
                entry.tags = tags
                currentEntry = entry
            }
        case "CreationTime":
            if var entry = currentEntry, let date = dateFormatter.date(from: text) {
                entry.creationDate = date
                currentEntry = entry
            }
        case "LastModificationTime":
            if var entry = currentEntry, let date = dateFormatter.date(from: text) {
                entry.modificationDate = date
                currentEntry = entry
            }
        case "Entry":
            if let entry = currentEntry {
                entries.append(entry)
            }
            currentEntry = nil
        case "History":
            isInHistory = false
        case "Group":
            if !groupStack.isEmpty {
                groupStack.removeLast()
            }
        default:
            break
        }
    }
}
