// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import AuthenticationServices

public enum CredentialExchangeImportError: Error {
    case noVaultSelected
}

public protocol CredentialExchangeImporting: AnyObject {
    
    @available(iOS 26.0, *)
    func extractToken(from userActivity: NSUserActivity) -> UUID?
    
    @available(iOS 26.0, *)
    func fetchCredentials(token: UUID) async throws -> ASExportedCredentialData
    
    @available(iOS 26.0, *)
    func convert(_ data: ASExportedCredentialData) throws(CredentialExchangeImportError) -> ExternalServiceImportResult
}


public final class CredentialExchangeImporter: CredentialExchangeImporting {
    private let context: ExternalServiceImportInteractor.ImportContext

    init(context: ExternalServiceImportInteractor.ImportContext) {
        self.context = context
    }

    @available(iOS 26.0, *)
    public func extractToken(from userActivity: NSUserActivity) -> UUID? {
        guard userActivity.activityType == ASCredentialExchangeActivity else { return nil }
        return userActivity.userInfo?[ASCredentialImportToken] as? UUID
    }

    @available(iOS 26.0, *)
    public func fetchCredentials(token: UUID) async throws -> ASExportedCredentialData {
        let manager = ASCredentialImportManager()
        return try await manager.importCredentials(token: token)
    }

    @available(iOS 26.0, *)
    public func convert(_ data: ASExportedCredentialData) throws(CredentialExchangeImportError) -> ExternalServiceImportResult {
        guard let vaultID = context.selectedVaultId else {
            throw .noVaultSelected
        }

        let protectionLevel = context.currentProtectionLevel
        var items: [ItemData] = []
        var secureNoteFallbackCount = 0

        // Build tag name to ID mapping from all items
        var tagNameToId: [String: ItemTagID] = [:]
        for account in data.accounts {
            for importableItem in account.items {
                for tagName in importableItem.tags {
                    if tagNameToId[tagName] == nil {
                        tagNameToId[tagName] = ItemTagID()
                    }
                }
            }
        }

        let allColors = ItemTagColor.allKnownCases
        let tags: [ItemTagData] = tagNameToId.enumerated().map { index, entry in
            let color = allColors[index % allColors.count]
            return ItemTagData(
                tagID: entry.value,
                vaultID: vaultID,
                name: entry.key,
                color: color,
                position: index,
                modificationDate: Date()
            )
        }

        for account in data.accounts {
            for importableItem in account.items {
                let tagIds: [ItemTagID]? = {
                    let ids = importableItem.tags.compactMap { tagNameToId[$0] }
                    return ids.isEmpty ? nil : ids
                }()

                let converted = convertItem(
                    importableItem,
                    vaultID: vaultID,
                    protectionLevel: protectionLevel,
                    tagIds: tagIds
                )
                if let itemData = converted.item {
                    items.append(itemData)
                    if converted.isSecureNoteFallback {
                        secureNoteFallbackCount += 1
                    }
                }
            }
        }

        return ExternalServiceImportResult(
            items: items,
            tags: tags,
            itemsConvertedToSecureNotes: secureNoteFallbackCount
        )
    }
}

// MARK: - Item Conversion

@available(iOS 26.0, *)
private extension CredentialExchangeImporter {

    struct ConvertedItem {
        let item: ItemData?
        let isSecureNoteFallback: Bool
    }

    func convertItem(
        _ importableItem: ASImportableItem,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ConvertedItem {
        let credentials = importableItem.credentials
        let itemID = makeItemID(from: importableItem.id)

        var basicAuth: ASImportableCredential.BasicAuthentication?
        var notes: [String] = []
        var creditCard: ASImportableCredential.CreditCard?
        var firstUnsupportedCredential: ASImportableCredential?

        for credential in credentials {
            switch credential {
            case .basicAuthentication(let value):
                basicAuth = basicAuth ?? value
            case .passkey:
                // Passkeys are intentionally not imported.
                break
            case .note(let value):
                if let noteText = value.content.value.nonBlankTrimmedOrNil {
                    notes.append(noteText)
                }
            case .creditCard(let value):
                creditCard = creditCard ?? value
                // Extract unused credit card fields
                if let unusedFields = extractUnusedCreditCardFields(value) {
                    notes.append(unusedFields)
                }
            case .customFields(let customFields):
                // Extract and append custom fields to notes
                if let formattedFields = formatCustomFields(customFields) {
                    notes.append(formattedFields)
                }
            default:
                firstUnsupportedCredential = firstUnsupportedCredential ?? credential
            }
        }

        let combinedNotes = notes.isEmpty ? nil : notes.joined(separator: "\n\n")

        if basicAuth != nil {
            let item = makeLoginItem(
                id: itemID,
                importableItem: importableItem,
                basicAuth: basicAuth,
                notes: combinedNotes,
                vaultID: vaultID,
                protectionLevel: protectionLevel,
                tagIds: tagIds
            )
            return ConvertedItem(item: item, isSecureNoteFallback: false)
        }

        if let creditCard {
            let item = makePaymentCardItem(
                id: itemID,
                importableItem: importableItem,
                credential: creditCard,
                notes: combinedNotes,
                vaultID: vaultID,
                protectionLevel: protectionLevel,
                tagIds: tagIds
            )
            return ConvertedItem(item: item, isSecureNoteFallback: false)
        }

        // Preserve unsupported credential data when present, while keeping all notes.
        if let firstUnsupportedCredential {
            let item = makeFallbackSecureNote(
                id: itemID,
                importableItem: importableItem,
                credential: firstUnsupportedCredential,
                notes: combinedNotes,
                vaultID: vaultID,
                protectionLevel: protectionLevel,
                tagIds: tagIds
            )
            return ConvertedItem(item: item, isSecureNoteFallback: true)
        }

        if let combinedNotes {
            let item = makeSecureNoteItem(
                id: itemID,
                importableItem: importableItem,
                noteText: combinedNotes,
                vaultID: vaultID,
                protectionLevel: protectionLevel,
                tagIds: tagIds
            )
            return ConvertedItem(item: item, isSecureNoteFallback: false)
        }

        return ConvertedItem(item: nil, isSecureNoteFallback: false)
    }

    func makeItemID(from data: Data) -> ItemID {
        guard data.count == 16 else { return ItemID() }
        return data.withUnsafeBytes { buffer in
            UUID(uuid: buffer.load(as: uuid_t.self))
        }
    }

    func makeMetadataDates(from importableItem: ASImportableItem) -> (creationDate: Date, modificationDate: Date) {
        let creationDate = importableItem.created ?? .importPasswordPlaceholder
        let modificationDate = importableItem.lastModified ?? creationDate
        return (creationDate, modificationDate)
    }

    func extractUnusedCreditCardFields(_ creditCard: ASImportableCredential.CreditCard) -> String? {
        var fields: [String] = []

        // Fields we don't store in payment card item but want to preserve in notes
        if let cardType = creditCard.cardType?.value.nonBlankTrimmedOrNil {
            fields.append("Card Type: \(cardType)")
        }

        if let pin = creditCard.pin?.value.nonBlankTrimmedOrNil {
            fields.append("PIN: \(pin)")
        }

        if let validFrom = creditCard.validFrom?.value.nonBlankTrimmedOrNil {
            fields.append("Valid From: \(validFrom)")
        }

        return fields.isEmpty ? nil : fields.joined(separator: "\n")
    }

    func formatCustomFields(_ customFields: ASImportableCredential.CustomFields) -> String? {
        var fields: [String] = []

        // Add label if present
        if let label = customFields.label?.nonBlankTrimmedOrNil {
            fields.append("[\(label)]")
        }

        // Add each custom field
        for (index, field) in customFields.fields.enumerated() {
            let fieldLabel = field.label?.nonBlankTrimmedOrNil ?? "Field \(index + 1)"
            if let value = field.value.nonBlankTrimmedOrNil {
                fields.append("\(fieldLabel): \(value)")
            }
        }

        return fields.isEmpty ? nil : fields.joined(separator: "\n")
    }

    // MARK: - Login Item

    func makeLoginItem(
        id: ItemID,
        importableItem: ASImportableItem,
        basicAuth: ASImportableCredential.BasicAuthentication?,
        notes: String?,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let name = importableItem.title.nonBlankTrimmedOrNil
        let metadataDates = makeMetadataDates(from: importableItem)

        var username: String?
        var password: Data?

        if let basicAuth {
            username = basicAuth.userName?.value.nonBlankTrimmedOrNil
            if let passwordString = basicAuth.password?.value.nonBlankTrimmedOrNil {
                password = context.encryptSecureField(passwordString, for: protectionLevel)
            }
        }

        let uris: [PasswordURI]? = {
            guard let urls = importableItem.scope?.urls, !urls.isEmpty else { return nil }
            return urls.compactMap { url in
                guard let urlString = url.absoluteString.nonBlankTrimmedOrNil else { return nil }
                return PasswordURI(uri: urlString, match: .domain)
            }
        }()

        let iconType = context.makeIconType(uri: uris?.first?.uri)

        return .login(.init(
            id: id,
            vaultId: vaultID,
            metadata: .init(
                creationDate: metadataDates.creationDate,
                modificationDate: metadataDates.modificationDate,
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
                iconType: iconType,
                uris: uris
            )
        ))
    }

    // MARK: - Payment Card Item

    func makePaymentCardItem(
        id: ItemID,
        importableItem: ASImportableItem,
        credential: ASImportableCredential.CreditCard,
        notes: String?,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let name = importableItem.title.nonBlankTrimmedOrNil
        let metadataDates = makeMetadataDates(from: importableItem)
        let cardNumberString = credential.number?.value.nonBlankTrimmedOrNil

        let cardNumber: Data? = {
            guard let value = cardNumberString else { return nil }
            return context.encryptSecureField(value, for: protectionLevel)
        }()

        let expirationDate: Data? = {
            guard let isoDate = credential.expiryDate?.value.nonBlankTrimmedOrNil,
                  let formatted = convertISOExpirationDate(isoDate) else { return nil }
            return context.encryptSecureField(formatted, for: protectionLevel)
        }()

        let securityCode: Data? = {
            guard let value = credential.verificationNumber?.value.nonBlankTrimmedOrNil else { return nil }
            return context.encryptSecureField(value, for: protectionLevel)
        }()

        let cardNumberMask = context.cardNumberMask(from: cardNumberString)
        let cardIssuer = context.detectCardIssuer(from: cardNumberString)

        return .paymentCard(.init(
            id: id,
            vaultId: vaultID,
            metadata: .init(
                creationDate: metadataDates.creationDate,
                modificationDate: metadataDates.modificationDate,
                protectionLevel: protectionLevel,
                trashedStatus: .no,
                tagIds: tagIds
            ),
            name: name,
            content: .init(
                name: name,
                cardHolder: credential.fullName?.value.nonBlankTrimmedOrNil,
                cardIssuer: cardIssuer,
                cardNumber: cardNumber,
                cardNumberMask: cardNumberMask,
                expirationDate: expirationDate,
                securityCode: securityCode,
                notes: notes
            )
        ))
    }

    // MARK: - Secure Note Item

    func makeSecureNoteItem(
        id: ItemID,
        importableItem: ASImportableItem,
        noteText: String,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let name = importableItem.title.nonBlankTrimmedOrNil
        let metadataDates = makeMetadataDates(from: importableItem)
        let text: Data? = {
            return context.encryptSecureField(noteText, for: protectionLevel)
        }()

        return .secureNote(.init(
            id: id,
            vaultId: vaultID,
            metadata: .init(
                creationDate: metadataDates.creationDate,
                modificationDate: metadataDates.modificationDate,
                protectionLevel: protectionLevel,
                trashedStatus: .no,
                tagIds: tagIds
            ),
            name: name,
            content: .init(
                name: name,
                text: text,
                additionalInfo: nil
            )
        ))
    }

    // MARK: - Fallback Secure Note

    func makeFallbackSecureNote(
        id: ItemID,
        importableItem: ASImportableItem,
        credential: ASImportableCredential,
        notes: String?,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let title = importableItem.title.nonBlankTrimmedOrNil
        let metadataDates = makeMetadataDates(from: importableItem)
        let credentialType = getCredentialTypeName(credential)
        let name = title.map { "\($0) (\(credentialType))" } ?? credentialType

        let formattedContent = formatCredentialAsKeyValuePairs(credential)
        let mergedText = context.mergeNote(notes, with: formattedContent) ?? formattedContent
        let text: Data? = context.encryptSecureField(mergedText, for: protectionLevel)

        return .secureNote(.init(
            id: id,
            vaultId: vaultID,
            metadata: .init(
                creationDate: metadataDates.creationDate,
                modificationDate: metadataDates.modificationDate,
                protectionLevel: protectionLevel,
                trashedStatus: .no,
                tagIds: tagIds
            ),
            name: name,
            content: .init(
                name: name,
                text: text,
                additionalInfo: nil
            )
        ))
    }

    func getCredentialTypeName(_ credential: ASImportableCredential) -> String {
        switch credential {
        case .address: return "Address"
        case .apiKey: return "API Key"
        case .basicAuthentication: return "Basic Authentication"
        case .creditCard: return "Credit Card"
        case .customFields: return "Custom Fields"
        case .driversLicense: return "Driver's License"
        case .generatedPassword: return "Generated Password"
        case .identityDocument: return "Identity Document"
        case .itemReference: return "Item Reference"
        case .note: return "Note"
        case .passkey: return "Passkey"
        case .passport: return "Passport"
        case .personName: return "Person Name"
        case .sshKey: return "SSH Key"
        case .totp: return "TOTP"
        case .wifi: return "WiFi"
        @unknown default: return "Unknown Credential"
        }
    }

    func formatCredentialAsKeyValuePairs(_ credential: ASImportableCredential) -> String {
        var pairs: [String] = []

        func appendPair(_ key: String, _ value: String?) {
            guard let trimmedValue = value?.nonBlankTrimmedOrNil else { return }
            pairs.append("\(key): \(trimmedValue)")
        }

        func appendPair(_ key: String, field: ASImportableEditableField?) {
            appendPair(key, field?.value)
        }

        func appendPair(_ key: String, data: Data?) {
            guard let data, !data.isEmpty else { return }
            pairs.append("\(key): \(data.base64EncodedString())")
        }

        switch credential {
        case .address(let address):
            appendPair("Street Address", field: address.streetAddress)
            appendPair("Postal Code", field: address.postalCode)
            appendPair("City", field: address.city)
            appendPair("Territory", field: address.territory)
            appendPair("Country", field: address.country)
            appendPair("Telephone", field: address.telephone)

        case .apiKey(let apiKey):
            appendPair("Key", field: apiKey.key)
            appendPair("Username", field: apiKey.userName)
            appendPair("Key Type", field: apiKey.keyType)
            appendPair("URL", field: apiKey.url)
            appendPair("Valid From", field: apiKey.validFrom)
            appendPair("Expiry Date", field: apiKey.expiryDate)

        case .basicAuthentication(let auth):
            appendPair("Username", field: auth.userName)
            appendPair("Password", field: auth.password)

        case .creditCard(let card):
            appendPair("Card Number", field: card.number)
            appendPair("Cardholder Name", field: card.fullName)
            appendPair("Card Type", field: card.cardType)
            appendPair("Security Code", field: card.verificationNumber)
            appendPair("PIN", field: card.pin)
            appendPair("Expiry Date", field: card.expiryDate)
            appendPair("Valid From", field: card.validFrom)

        case .customFields(let customFields):
            appendPair("Label", customFields.label)
            for (index, field) in customFields.fields.enumerated() {
                let fieldLabel = field.label?.nonBlankTrimmedOrNil ?? "Field \(index + 1)"
                appendPair(fieldLabel, field.value)
            }

        case .driversLicense(let license):
            appendPair("Full Name", field: license.fullName)
            appendPair("Birth Date", field: license.birthDate)
            appendPair("Issue Date", field: license.issueDate)
            appendPair("Expiry Date", field: license.expiryDate)
            appendPair("Issuing Authority", field: license.issuingAuthority)
            appendPair("Territory", field: license.territory)
            appendPair("Country", field: license.country)
            appendPair("License Number", field: license.licenseNumber)
            appendPair("License Class", field: license.licenseClass)

        case .generatedPassword(let genPassword):
            appendPair("Password", genPassword.password)

        case .identityDocument(let document):
            appendPair("Issuing Country", field: document.issuingCountry)
            appendPair("Document Number", field: document.documentNumber)
            appendPair("Identification Number", field: document.identificationNumber)
            appendPair("Nationality", field: document.nationality)
            appendPair("Full Name", field: document.fullName)
            appendPair("Birth Date", field: document.birthDate)
            appendPair("Birth Place", field: document.birthPlace)
            appendPair("Sex", field: document.sex)
            appendPair("Issue Date", field: document.issueDate)
            appendPair("Expiry Date", field: document.expiryDate)
            appendPair("Issuing Authority", field: document.issuingAuthority)

        case .itemReference(let reference):
            appendPair("Item ID", data: reference.reference.item)
            appendPair("Account ID", data: reference.reference.account)

        case .note(let note):
            appendPair("Content", note.content.value)

        case .passkey(let passkey):
            appendPair("Credential ID", data: passkey.credentialID)
            appendPair("Relying Party Identifier", passkey.relyingPartyIdentifier)
            appendPair("Username", passkey.userName)
            appendPair("User Display Name", passkey.userDisplayName)
            appendPair("User Handle", data: passkey.userHandle)
            appendPair("Key", data: passkey.key)

        case .passport(let passport):
            appendPair("Issuing Country", field: passport.issuingCountry)
            appendPair("Passport Type", field: passport.passportType)
            appendPair("Passport Number", field: passport.passportNumber)
            appendPair("National ID Number", field: passport.nationalIdentificationNumber)
            appendPair("Nationality", field: passport.nationality)
            appendPair("Full Name", field: passport.fullName)
            appendPair("Birth Date", field: passport.birthDate)
            appendPair("Birth Place", field: passport.birthPlace)
            appendPair("Sex", field: passport.sex)
            appendPair("Issue Date", field: passport.issueDate)
            appendPair("Expiry Date", field: passport.expiryDate)
            appendPair("Issuing Authority", field: passport.issuingAuthority)

        case .personName(let personName):
            appendPair("Title", field: personName.title)
            appendPair("Given Name", field: personName.given)
            appendPair("Informal Given Name", field: personName.givenInformal)
            appendPair("Additional Given Name", field: personName.given2)
            appendPair("Surname Prefix", field: personName.surnamePrefix)
            appendPair("Surname", field: personName.surname)
            appendPair("Additional Surname", field: personName.surname2)
            appendPair("Credentials", field: personName.credentials)
            appendPair("Generation", field: personName.generation)

        case .sshKey(let sshKey):
            appendPair("Key Type", sshKey.keyType)
            appendPair("Private Key", data: sshKey.privateKey)
            appendPair("Key Comment", sshKey.keyComment)
            appendPair("Creation Date", field: sshKey.creationDate)
            appendPair("Expiry Date", field: sshKey.expiryDate)
            appendPair("Key Generation Source", field: sshKey.keyGenerationSource)

        case .totp(let totp):
            appendPair("Secret", data: totp.secret)
            pairs.append("Digits: \(totp.digits)")
            pairs.append("Period: \(totp.period)")
            pairs.append("Algorithm: \(totp.algorithm.rawValue.uppercased())")
            appendPair("Username", totp.userName)
            appendPair("Issuer", totp.issuer)

        case .wifi(let wifi):
            appendPair("SSID", field: wifi.ssid)
            appendPair("Network Security Type", field: wifi.networkSecurityType)
            appendPair("Passphrase", field: wifi.passphrase)
            appendPair("Hidden", field: wifi.hidden)

        @unknown default:
            pairs.append(String(describing: credential))
        }

        return pairs.isEmpty ? "No data available" : pairs.joined(separator: "\n")
    }

    // MARK: - Expiration Date Conversion

    /// Converts ISO 8601 "YYYY-MM" format to "MM / YY" format
    func convertISOExpirationDate(_ isoDate: String) -> String? {
        let components = isoDate.split(separator: "-")
        guard components.count == 2,
              let year = components.first,
              let month = components.last,
              year.count == 4,
              month.count == 2 else {
            return nil
        }
        let shortYear = year.suffix(2)
        return "\(month)/\(shortYear)"
    }
}
