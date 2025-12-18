// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import SwiftCSV
import ZIPFoundation

extension ExternalServiceImportInteractor {

    struct ApplePasswordsImporter {
        let context: ImportContext

        func importMobile(_ content: Data) async throws(ExternalServiceImportError) -> [ItemData] {
            guard let archive = try? Archive(data: content, accessMode: .read, pathEncoding: .utf8) else {
                throw .wrongFormat
            }

            guard let passwordsCSVFile = archive.first(where: { $0.path.hasSuffix("csv") }) else {
                throw .wrongFormat
            }

            do {
                var fileData = Data()
                _ = try archive.extract(passwordsCSVFile) { data in
                    fileData.append(data)
                }
                guard let csvString = String(data: fileData, encoding: .utf8) else {
                    throw ExternalServiceImportError.wrongFormat
                }
                return try await importCSV(csvString)
            } catch let error as ExternalServiceImportError {
                throw error
            } catch {
                throw .wrongFormat
            }
        }

        func importDesktop(_ content: Data) async throws(ExternalServiceImportError) -> [ItemData] {
            guard let csvString = String(data: content, encoding: .utf8) else {
                throw .wrongFormat
            }
            return try await importCSV(csvString)
        }
    }
}

// MARK: - Private Helpers

private extension ExternalServiceImportInteractor.ApplePasswordsImporter {

    func importCSV(_ csvContent: String) async throws(ExternalServiceImportError) -> [ItemData] {
        guard let vaultID = context.selectedVaultId else {
            throw .wrongFormat
        }
        var items: [ItemData] = []
        let protectionLevel = context.currentProtectionLevel

        do {
            let csv = try CSV<Enumerated>(string: csvContent, delimiter: .comma)

            let knownCSVColumns: Set<String> = [
                "Title", "URL", "Username", "Password", "Notes"
            ]

            guard csv.header.containsAll(Array(knownCSVColumns)) else {
                throw ExternalServiceImportError.wrongFormat
            }
            try csv.enumerateAsDict { dict in
                guard dict.allValuesEmpty == false else { return }

                let username = dict["Username"]?.nilIfEmpty
                let name: String? = {
                    let name = dict["Title"].formattedName
                    if let name, let username {
                        let suffixToRemove = " (\(username))"
                        if name.hasSuffix(suffixToRemove) {
                            return String(name.dropLast(suffixToRemove.count))
                        }
                    }
                    return name
                }()
                let uris: [PasswordURI]? = {
                    guard let urlString = dict["URL"]?.nilIfEmpty else { return nil }
                    let uri = PasswordURI(uri: urlString, match: .domain)
                    return [uri]
                }()
                let password: Data? = {
                    if let passwordString = dict["Password"]?.nilIfEmpty,
                       let password = context.encryptSecureField(passwordString, for: protectionLevel) {
                        return password
                    }
                    return nil
                }()

                let csvAdditionalInfo = context.formatDictionary(dict, excludingKeys: knownCSVColumns)
                let notes = context.mergeNote(dict["Notes"]?.nilIfEmpty, with: csvAdditionalInfo)

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
