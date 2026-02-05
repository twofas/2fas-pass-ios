// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import AuthenticationServices

@available(iOS 26.0, *)
public protocol CredentialExchangeExporting: AnyObject {
    func convert(_ items: [ItemData]) -> ASExportedCredentialData
}

@available(iOS 26.0, *)
public final class CredentialExchangeExporter: CredentialExchangeExporting {

    private let itemsInteractor: ItemsInteracting
    private let tagInteractor: TagInteracting
    private let mainRepository: MainRepository

    init(itemsInteractor: ItemsInteracting, tagInteractor: TagInteracting, mainRepository: MainRepository) {
        self.itemsInteractor = itemsInteractor
        self.tagInteractor = tagInteractor
        self.mainRepository = mainRepository
    }

    public func convert(_ items: [ItemData]) -> ASExportedCredentialData {
        let bundleIdentifier = mainRepository.appBundleIdentifier ?? ""
        let displayName = mainRepository.appDisplayName ?? ""

        let tagNameByID: [ItemTagID: String] = tagInteractor.listAllTags()
            .reduce(into: [:]) { $0[$1.tagID] = $1.name }

        let importableItems = items.compactMap { convertItem($0, tagNameByID: tagNameByID) }

        let account = ASImportableAccount(
            id: Data(UUID().uuidString.utf8),
            userName: "",
            email: "",
            collections: [],
            items: importableItems
        )

        return ASExportedCredentialData(
            accounts: [account],
            formatVersion: .v1,
            exporterRelyingPartyIdentifier: bundleIdentifier,
            exporterDisplayName: displayName,
            timestamp: mainRepository.currentDate
        )
    }
}

// MARK: - Item Conversion

@available(iOS 26.0, *)
private extension CredentialExchangeExporter {

    func convertItem(_ item: ItemData, tagNameByID: [ItemTagID: String]) -> ASImportableItem? {
        let tags = item.tagIds?.compactMap { tagNameByID[$0] } ?? []
        switch item {
        case .login(let data):
            return convertLoginItem(data, protectionLevel: item.protectionLevel, tags: tags)
        case .secureNote(let data):
            return convertSecureNoteItem(data, protectionLevel: item.protectionLevel, tags: tags)
        case .paymentCard(let data):
            return convertPaymentCardItem(data, protectionLevel: item.protectionLevel, tags: tags)
        case .raw:
            return nil
        }
    }

    // MARK: - Login

    func convertLoginItem(
        _ data: LoginItemData,
        protectionLevel: ItemProtectionLevel,
        tags: [String]
    ) -> ASImportableItem? {
        var credentials: [ASImportableCredential] = []

        // Basic authentication
        let decryptedPassword = data.password.flatMap {
            itemsInteractor.decrypt($0, isSecureField: true, protectionLevel: protectionLevel)
        }
        if decryptedPassword != nil || data.username != nil {
            let userName = ASImportableEditableField(
                id: nil, fieldType: .string, value: data.username ?? ""
            )
            let passwordField = decryptedPassword.map {
                ASImportableEditableField(id: nil, fieldType: .concealedString, value: $0)
            }
            credentials.append(.basicAuthentication(.init(
                userName: userName,
                password: passwordField
            )))
        }

        // TOTP from notes
        if let totp = parseTOTPFromNotes(data.notes, userName: data.username) {
            credentials.append(.totp(totp))
        }

        guard !credentials.isEmpty else { return nil }

        let scope: ASImportableCredentialScope? = {
            guard let uris = data.uris, !uris.isEmpty else { return nil }
            let urls = uris.compactMap { URL(string: $0.uri) }
            guard !urls.isEmpty else { return nil }
            return ASImportableCredentialScope(urls: urls)
        }()

        return ASImportableItem(
            id: Data(data.id.uuidString.utf8),
            created: data.creationDate,
            lastModified: data.modificationDate,
            title: data.name ?? "",
            scope: scope,
            credentials: credentials,
            tags: tags
        )
    }

    // MARK: - Secure Note

    func convertSecureNoteItem(
        _ data: SecureNoteItemData,
        protectionLevel: ItemProtectionLevel,
        tags: [String]
    ) -> ASImportableItem? {
        var noteText = ""
        if let encryptedText = data.content.text,
           let decrypted = itemsInteractor.decrypt(
               encryptedText, isSecureField: true, protectionLevel: protectionLevel
           ) {
            noteText = decrypted
        }

        guard !noteText.isEmpty else { return nil }

        let contentField = ASImportableEditableField(
            id: nil, fieldType: .string, value: noteText
        )
        let credential = ASImportableCredential.note(.init(content: contentField))

        return ASImportableItem(
            id: Data(data.id.uuidString.utf8),
            created: data.creationDate,
            lastModified: data.modificationDate,
            title: data.name ?? "",
            credentials: [credential],
            tags: tags
        )
    }

    // MARK: - Payment Card

    func convertPaymentCardItem(
        _ data: PaymentCardItemData,
        protectionLevel: ItemProtectionLevel,
        tags: [String]
    ) -> ASImportableItem? {
        let number: ASImportableEditableField? = {
            guard let encrypted = data.content.cardNumber,
                  let decrypted = itemsInteractor.decrypt(
                      encrypted, isSecureField: true, protectionLevel: protectionLevel
                  ) else { return nil }
            return ASImportableEditableField(
                id: nil, fieldType: .concealedString, value: decrypted
            )
        }()

        let expiryDate: ASImportableEditableField? = {
            guard let encrypted = data.content.expirationDate,
                  let decrypted = itemsInteractor.decrypt(
                      encrypted, isSecureField: true, protectionLevel: protectionLevel
                  ) else { return nil }
            return ASImportableEditableField(
                id: nil, fieldType: .yearMonth, value: decrypted
            )
        }()

        let verificationNumber: ASImportableEditableField? = {
            guard let encrypted = data.content.securityCode,
                  let decrypted = itemsInteractor.decrypt(
                      encrypted, isSecureField: true, protectionLevel: protectionLevel
                  ) else { return nil }
            return ASImportableEditableField(
                id: nil, fieldType: .concealedString, value: decrypted
            )
        }()

        let fullName: ASImportableEditableField? = {
            guard let holder = data.content.cardHolder else { return nil }
            return ASImportableEditableField(
                id: nil, fieldType: .string, value: holder
            )
        }()

        let credential = ASImportableCredential.creditCard(.init(
            number: number,
            fullName: fullName,
            cardType: nil,
            verificationNumber: verificationNumber,
            pin: nil,
            expiryDate: expiryDate,
            validFrom: nil
        ))

        return ASImportableItem(
            id: Data(data.id.uuidString.utf8),
            created: data.creationDate,
            lastModified: data.modificationDate,
            title: data.name ?? "",
            credentials: [credential],
            tags: tags
        )
    }

    // MARK: - TOTP Parsing

    func parseTOTPFromNotes(_ notes: String?, userName: String?) -> ASImportableCredential.TOTP? {
        guard let notes, let range = notes.range(of: "otpauth://totp/") else { return nil }
        let uriSubstring = notes[range.lowerBound...]
        guard let uriString = uriSubstring.components(separatedBy: .whitespacesAndNewlines).first,
              let components = URLComponents(string: uriString) else { return nil }

        let queryItems = components.queryItems ?? []

        guard let secretString = queryItems.first(where: { $0.name == "secret" })?.value,
              let secret = base32Decode(secretString),
              !secret.isEmpty else { return nil }

        let digits: UInt16 = queryItems.first(where: { $0.name == "digits" })
            .flatMap { UInt16($0.value ?? "") } ?? 6

        let period: UInt16 = queryItems.first(where: { $0.name == "period" })
            .flatMap { UInt16($0.value ?? "") } ?? 30

        let algorithm: ASImportableCredential.TOTP.Algorithm = {
            switch queryItems.first(where: { $0.name == "algorithm" })?.value?.uppercased() {
            case "SHA256": return .sha256
            case "SHA512": return .sha512
            default: return .sha1
            }
        }()

        let issuer = queryItems.first(where: { $0.name == "issuer" })?.value

        return .init(
            secret: secret,
            period: period,
            digits: digits,
            userName: userName,
            algorithm: algorithm,
            issuer: issuer
        )
    }

    func base32Decode(_ string: String) -> Data? {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        let uppercased = string.uppercased().filter { $0 != "=" }

        var buffer: UInt64 = 0
        var bitsLeft = 0
        var result: [UInt8] = []

        for char in uppercased {
            guard let index = alphabet.firstIndex(of: char) else { return nil }
            let value = UInt64(alphabet.distance(from: alphabet.startIndex, to: index))
            buffer = (buffer << 5) | value
            bitsLeft += 5

            if bitsLeft >= 8 {
                bitsLeft -= 8
                result.append(UInt8((buffer >> bitsLeft) & 0xFF))
            }
        }

        return Data(result)
    }
}
