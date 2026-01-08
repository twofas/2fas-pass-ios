// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

struct KeePassXMLEntry {
    var fields: [String: String]
    var tags: [String]
    var groupPath: [String]
    var creationDate: Date?
    var modificationDate: Date?
}

enum KeePassXMLSource: Equatable {
    case keePass
    case keePassXC

    func generatorMatches(_ value: String) -> Bool {
        switch self {
        case .keePass:
            return value.caseInsensitiveCompare("KeePass") == .orderedSame
        case .keePassXC:
            return value.localizedCaseInsensitiveContains("KeePassXC")
        }
    }
}

final class KeePassXMLParser: NSObject, XMLParserDelegate {
    private let source: KeePassXMLSource

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
    private var isGeneratorMatch = false
    private let baseDate = Date(timeIntervalSince1970: -62135596800)

    init(source: KeePassXMLSource) {
        self.source = source
    }

    func parse(_ data: Data) throws(ExternalServiceImportError) -> [KeePassXMLEntry] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse(), isKeePassFile, isGeneratorMatch else {
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
        case "Generator":
            if !text.isEmpty {
                isGeneratorMatch = source.generatorMatches(text)
            }
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
                    .split { $0 == ";" || $0 == "," }
                    .map { String($0).trim() }
                    .filter { !$0.isEmpty }
                entry.tags = tags
                currentEntry = entry
            }
        case "CreationTime":
            if var entry = currentEntry, let date = parseDate(from: text) {
                entry.creationDate = date
                currentEntry = entry
            }
        case "LastModificationTime":
            if var entry = currentEntry, let date = parseDate(from: text) {
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

    private func parseDate(from string: String) -> Date? {
        if let date = dateFormatter.date(from: string) {
            return date
        }
        guard let data = Data(base64Encoded: string), data.count == 8 else {
            return nil
        }
        let seconds = data.withUnsafeBytes { $0.load(as: UInt64.self) }
        return baseDate.addingTimeInterval(TimeInterval(UInt64(littleEndian: seconds)))
    }
}
