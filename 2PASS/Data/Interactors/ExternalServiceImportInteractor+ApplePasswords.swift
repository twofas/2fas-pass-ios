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
                var items: [ItemData] = []

                // Import passwords from CSV
                var csvData = Data()
                _ = try archive.extract(passwordsCSVFile) { data in
                    csvData.append(data)
                }
                guard let csvString = String(data: csvData, encoding: .utf8) else {
                    throw ExternalServiceImportError.wrongFormat
                }
                items.append(contentsOf: try await importCSV(csvString))

                // Import payment cards from JSON if present
                if let paymentCardsFile = archive.first(where: { $0.path.hasSuffix("PaymentCards.json") }) {
                    var jsonData = Data()
                    _ = try archive.extract(paymentCardsFile) { data in
                        jsonData.append(data)
                    }
                    items.append(contentsOf: try await importPaymentCardsJSON(jsonData))
                }

                return items
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

                let username = dict["Username"]?.nonBlankTrimmedOrNil
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
                    guard let urlString = dict["URL"]?.nonBlankTrimmedOrNil else { return nil }
                    let uri = PasswordURI(uri: urlString, match: .domain)
                    return [uri]
                }()
                let password: Data? = {
                    if let passwordString = dict["Password"]?.nonBlankTrimmedOrNil,
                       let password = context.encryptSecureField(passwordString, for: protectionLevel) {
                        return password
                    }
                    return nil
                }()

                let csvAdditionalInfo = context.formatDictionary(dict, excludingKeys: knownCSVColumns)
                let notes = context.mergeNote(dict["Notes"]?.nonBlankTrimmedOrNil, with: csvAdditionalInfo)

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

    func importPaymentCardsJSON(_ jsonData: Data) async throws(ExternalServiceImportError) -> [ItemData] {
        guard let vaultID = context.selectedVaultId else {
            throw .wrongFormat
        }

        let protectionLevel = context.currentProtectionLevel

        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let parsed = try decoder.decode(ApplePaymentCards.self, from: jsonData)
            var items: [ItemData] = []

            for rawCard in parsed.paymentCards {
                let card = ApplePaymentCard(rawCard)

                let cardName = card.cardName?.nonBlankTrimmedOrNil
                let name: String = {
                    var output = ""
                    if let cardName {
                        output.append("\(cardName) ")
                    }
                    return output + "(Payment Card)"
                }()

                // Format all card data as text
                let cardInfo = context.formatDictionary(card.rawData)

                let text: Data? = {
                    if let info = cardInfo,
                       let encrypted = context.encryptSecureField(info, for: protectionLevel) {
                        return encrypted
                    }
                    return nil
                }()

                items.append(.secureNote(.init(
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
                        text: text,
                        additionalInfo: nil
                    )
                )))
            }

            return items
        } catch {
            throw .wrongFormat
        }
    }
}

// MARK: - Apple PaymentCards JSON Model

private struct ApplePaymentCards: Decodable {
    let paymentCards: [[String: AnyCodable]]
}

private struct ApplePaymentCard {
    static let knownKeys: Set<String> = [
        "card_number", "card_name", "cardholder_name",
        "card_expiration_month", "card_expiration_year",
        "card_last_used_time_usec"
    ]

    let rawData: [String: Any]
    let unknownData: [String: Any]

    init(_ rawData: [String: AnyCodable]) {
        self.rawData = rawData.mapValues { $0.value }
        self.unknownData = self.rawData.filter { !Self.knownKeys.contains($0.key) }
    }

    var cardNumber: String? {
        rawData["card_number"] as? String
    }

    var cardName: String? {
        rawData["card_name"] as? String
    }

    var cardholderName: String? {
        rawData["cardholder_name"] as? String
    }

    var cardExpirationMonth: Int? {
        rawData["card_expiration_month"] as? Int
    }

    var cardExpirationYear: Int? {
        rawData["card_expiration_year"] as? Int
    }
}
