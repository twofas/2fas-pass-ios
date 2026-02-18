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
    private let uriInteractor: URIInteracting
    private let mainRepository: MainRepository

    init(itemsInteractor: ItemsInteracting, tagInteractor: TagInteracting, uriInteractor: URIInteracting, mainRepository: MainRepository) {
        self.itemsInteractor = itemsInteractor
        self.tagInteractor = tagInteractor
        self.uriInteractor = uriInteractor
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
        case .wifi(let data):
            return convertWifiItem(data, protectionLevel: item.protectionLevel, tags: tags)
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

        // Notes
        if let notes = data.notes?.nonBlankTrimmedOrNil {
            let noteField = ASImportableEditableField(id: nil, fieldType: .string, value: notes)
            credentials.append(.note(.init(content: noteField)))
        }

        guard !credentials.isEmpty else { return nil }

        let scope: ASImportableCredentialScope? = {
            guard let uris = data.uris, !uris.isEmpty else { return nil }
            let urls = uris.compactMap { uriInteractor.normalizeURL($0.uri) }
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
                  ),
                  let isoDate = convertExpirationDateToISO(decrypted) else { return nil }
            return ASImportableEditableField(
                id: nil, fieldType: .yearMonth, value: isoDate
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

        let cardCredential = ASImportableCredential.creditCard(.init(
            number: number,
            fullName: fullName,
            cardType: nil,
            verificationNumber: verificationNumber,
            pin: nil,
            expiryDate: expiryDate,
            validFrom: nil
        ))

        var credentials: [ASImportableCredential] = [cardCredential]

        if let notes = data.content.notes?.nonBlankTrimmedOrNil {
            let noteField = ASImportableEditableField(id: nil, fieldType: .string, value: notes)
            credentials.append(.note(.init(content: noteField)))
        }

        return ASImportableItem(
            id: Data(data.id.uuidString.utf8),
            created: data.creationDate,
            lastModified: data.modificationDate,
            title: data.name ?? "",
            credentials: credentials,
            tags: tags
        )
    }

    // MARK: - WiFi

    func convertWifiItem(
        _ data: WiFiItemData,
        protectionLevel: ItemProtectionLevel,
        tags: [String]
    ) -> ASImportableItem? {
        let content = data.content

        let ssid = ASImportableEditableField(id: nil, fieldType: .string, value: content.ssid ?? "")

        let networkSecurityType = ASImportableEditableField(
            id: nil, fieldType: .wifiNetworkSecurityType, value: content.securityType.cxfValue
        )

        let passphrase: ASImportableEditableField? = content.password.flatMap {
            itemsInteractor.decrypt($0, isSecureField: true, protectionLevel: protectionLevel)
        }.map {
            ASImportableEditableField(id: nil, fieldType: .concealedString, value: $0)
        }

        let hidden = ASImportableEditableField(
            id: nil, fieldType: .boolean, value: content.hidden ? "true" : "false"
        )

        let wifiCredential = ASImportableCredential.wifi(.init(
            ssid: ssid,
            networkSecurityType: networkSecurityType,
            passphrase: passphrase,
            hidden: hidden
        ))

        var credentials: [ASImportableCredential] = [wifiCredential]

        if let notes = content.notes?.nonBlankTrimmedOrNil {
            let noteField = ASImportableEditableField(id: nil, fieldType: .string, value: notes)
            credentials.append(.note(.init(content: noteField)))
        }

        return ASImportableItem(
            id: Data(data.id.uuidString.utf8),
            created: data.creationDate,
            lastModified: data.modificationDate,
            title: data.name ?? "",
            credentials: credentials,
            tags: tags
        )
    }

    // MARK: - Expiration Date Conversion

    /// Converts "MM / YY" format to ISO 8601 "YYYY-MM" format
    func convertExpirationDateToISO(_ dateString: String) -> String? {
        let digits = dateString.filter { $0.isNumber }
        guard digits.count == 4 else { return nil }

        let month = String(digits.prefix(2))
        let year = String(digits.suffix(2))

        guard let monthInt = Int(month), (1...12).contains(monthInt) else { return nil }

        let fullYear = "20" + year
        return "\(fullYear)-\(month)"
    }
}
