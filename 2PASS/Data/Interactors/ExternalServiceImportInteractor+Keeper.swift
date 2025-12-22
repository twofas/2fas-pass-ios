// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

extension ExternalServiceImportInteractor {

    struct KeeperImporter {
        let context: ImportContext

        func `import`(_ content: Data) async throws(ExternalServiceImportError) -> ExternalServiceImportResult {
            guard let parsedJSON = try? context.jsonDecoder.decode(Keeper.self, from: content) else {
                throw .wrongFormat
            }
            guard let vaultID = context.selectedVaultId else {
                throw .wrongFormat
            }
            var items: [ItemData] = []
            var itemsConvertedToSecureNotes = 0
            let protectionLevel = context.currentProtectionLevel

            // Create tags from folders
            var folderToTagId: [String: ItemTagID] = [:]
            var tags: [ItemTagData] = []

            parsedJSON.records?.forEach { record in
                // Handle folder -> tag mapping
                let tagIds: [ItemTagID]? = {
                    guard let folders = record.folders,
                          let firstFolder = folders.first,
                          let folderName = firstFolder.folder?.nonBlankTrimmedOrNil else { return nil }
                    if let existingTagId = folderToTagId[folderName] {
                        return [existingTagId]
                    }
                    let newTagId = ItemTagID()
                    folderToTagId[folderName] = newTagId
                    tags.append(ItemTagData(
                        tagID: newTagId,
                        vaultID: vaultID,
                        name: folderName,
                        color: .gray,
                        position: tags.count,
                        modificationDate: Date()
                    ))
                    return [newTagId]
                }()

                let recordType = record.type ?? "login"

                switch recordType {
                case "login":
                    if let loginItem = parseLogin(
                        record: record,
                        vaultID: vaultID,
                        protectionLevel: protectionLevel,
                        tagIds: tagIds
                    ) {
                        items.append(loginItem)
                    }
                case "encryptedNotes":
                    if let noteItem = parseSecureNote(
                        record: record,
                        vaultID: vaultID,
                        protectionLevel: protectionLevel,
                        tagIds: tagIds
                    ) {
                        items.append(noteItem)
                    }
                case "bankCard":
                    if let cardItem = parsePaymentCard(
                        record: record,
                        vaultID: vaultID,
                        protectionLevel: protectionLevel,
                        tagIds: tagIds
                    ) {
                        items.append(cardItem)
                    }
                default:
                    // Convert unsupported types to secure notes
                    if let noteItem = parseAsSecureNote(
                        record: record,
                        vaultID: vaultID,
                        protectionLevel: protectionLevel,
                        tagIds: tagIds
                    ) {
                        items.append(noteItem)
                        itemsConvertedToSecureNotes += 1
                    }
                }
            }

            return ExternalServiceImportResult(
                items: items,
                tags: tags,
                itemsConvertedToSecureNotes: itemsConvertedToSecureNotes
            )
        }
    }
}

// MARK: - Parsing Methods

private extension ExternalServiceImportInteractor.KeeperImporter {

    func parseLogin(
        record: Keeper.Record,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let name = record.title.formattedName
        let notes = record.notes?.nonBlankTrimmedOrNil
        let username = record.login?.nonBlankTrimmedOrNil
        let password: Data? = {
            if let passwordString = record.password?.nonBlankTrimmedOrNil {
                return context.encryptSecureField(passwordString, for: protectionLevel)
            }
            return nil
        }()

        let uris: [PasswordURI]? = {
            guard let urlString = record.loginUrl?.nonBlankTrimmedOrNil else { return nil }
            let uri = PasswordURI(uri: urlString, match: .domain)
            return [uri]
        }()

        let customFieldsInfo = formatCustomFields(record.customFields)
        let mergedNotes = context.mergeNote(notes, with: customFieldsInfo)

        return .login(.init(
            id: .init(),
            vaultId: vaultID,
            metadata: .init(
                creationDate: Date.importPasswordPlaceholder,
                modificationDate: Date.importPasswordPlaceholder,
                protectionLevel: protectionLevel,
                trashedStatus: .no,
                tagIds: tagIds
            ),
            name: name,
            content: .init(
                name: name,
                username: username,
                password: password,
                notes: mergedNotes,
                iconType: context.makeIconType(uri: uris?.first?.uri),
                uris: uris
            )
        ))
    }

    func parseSecureNote(
        record: Keeper.Record,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let name = record.title.formattedName

        // For encrypted notes, the main content is in custom_fields.$note::1
        let noteContent = record.customFields?.note
        let recordNotes = record.notes?.nonBlankTrimmedOrNil

        // Combine the note content with record notes
        let fullNoteText = context.mergeNote(noteContent, with: recordNotes)

        let text: Data? = {
            if let note = fullNoteText,
               let encrypted = context.encryptSecureField(note, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()

        // Format remaining custom fields (excluding note)
        let customFieldsInfo = formatCustomFields(record.customFields, excludeNote: true)

        return .secureNote(.init(
            id: .init(),
            vaultId: vaultID,
            metadata: .init(
                creationDate: Date.importPasswordPlaceholder,
                modificationDate: Date.importPasswordPlaceholder,
                protectionLevel: protectionLevel,
                trashedStatus: .no,
                tagIds: tagIds
            ),
            name: name,
            content: .init(
                name: name,
                text: text,
                additionalInfo: customFieldsInfo
            )
        ))
    }

    func parsePaymentCard(
        record: Keeper.Record,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let name = record.title.formattedName
        let notes = record.notes?.nonBlankTrimmedOrNil

        // Extract card details from custom_fields
        let paymentCard = record.customFields?.paymentCard
        let cardHolder = record.customFields?.cardholderName
        let pinCode = record.customFields?.pinCode

        let cardNumberString = paymentCard?.cardNumber
        let securityCodeString = paymentCard?.cardSecurityCode
        let expirationDateString = paymentCard?.cardExpirationDate

        let cardNumber: Data? = {
            if let value = cardNumberString,
               let encrypted = context.encryptSecureField(value, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()

        let expirationDate: Data? = {
            if let value = expirationDateString,
               let encrypted = context.encryptSecureField(value, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()

        let securityCode: Data? = {
            if let value = securityCodeString,
               let encrypted = context.encryptSecureField(value, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()

        let cardNumberMask = context.cardNumberMask(from: cardNumberString)
        let cardIssuer = context.detectCardIssuer(from: cardNumberString)

        // Add PIN code to notes if present
        var additionalInfo: String?
        if let pin = pinCode {
            additionalInfo = "PIN: \(pin)"
        }

        let mergedNotes = context.mergeNote(notes, with: additionalInfo)

        return .paymentCard(.init(
            id: .init(),
            vaultId: vaultID,
            metadata: .init(
                creationDate: Date.importPasswordPlaceholder,
                modificationDate: Date.importPasswordPlaceholder,
                protectionLevel: protectionLevel,
                trashedStatus: .no,
                tagIds: tagIds
            ),
            name: name,
            content: .init(
                name: name,
                cardHolder: cardHolder,
                cardIssuer: cardIssuer,
                cardNumber: cardNumber,
                cardNumberMask: cardNumberMask,
                expirationDate: expirationDate,
                securityCode: securityCode,
                notes: mergedNotes
            )
        ))
    }

    func parseAsSecureNote(
        record: Keeper.Record,
        vaultID: VaultID,
        protectionLevel: ItemProtectionLevel,
        tagIds: [ItemTagID]?
    ) -> ItemData? {
        let recordType = record.type ?? "Unknown"
        let name: String = {
            var output = ""
            if let title = record.title.formattedName {
                output.append("\(title) ")
            }
            return output + "(\(formatTypeName(recordType)))"
        }()

        // Gather all data into a single note
        var noteComponents: [String] = []

        if let login = record.login?.nonBlankTrimmedOrNil {
            noteComponents.append("Login: \(login)")
        }
        if let password = record.password?.nonBlankTrimmedOrNil {
            noteComponents.append("Password: \(password)")
        }
        if let url = record.loginUrl?.nonBlankTrimmedOrNil {
            noteComponents.append("URL: \(url)")
        }
        if let customFieldsInfo = formatCustomFields(record.customFields) {
            noteComponents.append(customFieldsInfo)
        }
        if let notes = record.notes?.nonBlankTrimmedOrNil {
            noteComponents.append(notes)
        }

        let fullNoteText = noteComponents.isEmpty ? nil : noteComponents.joined(separator: "\n")

        let text: Data? = {
            if let note = fullNoteText,
               let encrypted = context.encryptSecureField(note, for: protectionLevel) {
                return encrypted
            }
            return nil
        }()

        return .secureNote(.init(
            id: .init(),
            vaultId: vaultID,
            metadata: .init(
                creationDate: Date.importPasswordPlaceholder,
                modificationDate: Date.importPasswordPlaceholder,
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

    func formatTypeName(_ type: String) -> String {
        // Convert camelCase to Title Case with spaces
        type.replacingOccurrences(
            of: "([a-z])([A-Z])",
            with: "$1 $2",
            options: .regularExpression
        ).capitalizedFirstLetter
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    func formatDateLabel(_ label: String) -> String {
        // Convert camelCase label like "dateActive" to "Date Active"
        label.replacingOccurrences(
            of: "([a-z])([A-Z])",
            with: "$1 $2",
            options: .regularExpression
        ).capitalizedFirstLetter
    }

    func formatCustomFields(_ customFields: Keeper.CustomFields?, excludeNote: Bool = false) -> String? {
        guard let customFields else { return nil }

        var components: [String] = []

        // Add simple text fields
        for text in customFields.textFields {
            components.append("\(text)")
        }
        
        // Add multiline fields
        for multiline in customFields.multilineFields {
            components.append("\(multiline)")
        }
        
        // Format name fields
        for name in customFields.names {
            let fullName = [name.first, name.middle, name.last]
                .compactMap { $0 }
                .joined(separator: " ")
            if !fullName.isEmpty {
                components.append("Name: \(fullName)")
            }
        }

        // Format address fields
        for address in customFields.addresses {
            var addressParts: [String] = []
            if let street1 = address.street1 { addressParts.append(street1) }
            if let street2 = address.street2 { addressParts.append(street2) }
            if let city = address.city { addressParts.append(city) }
            if let state = address.state { addressParts.append(state) }
            if let zip = address.zip { addressParts.append(zip) }
            if let country = address.country { addressParts.append(country) }
            if !addressParts.isEmpty {
                components.append("Address: \(addressParts.joined(separator: ", "))")
            }
        }

        // Format phone fields
        for phone in customFields.phones {
            var phoneStr = ""
            if let region = phone.region { phoneStr += "+\(region) " }
            if let number = phone.number { phoneStr += number }
            if let ext = phone.ext { phoneStr += " ext. \(ext)" }
            if !phoneStr.isEmpty {
                components.append("Phone: \(phoneStr.trimmingCharacters(in: .whitespaces))")
            }
        }

        // Format host fields
        for host in customFields.hosts {
            var hostStr = host.hostName ?? ""
            if let port = host.port { hostStr += ":\(port)" }
            if !hostStr.isEmpty {
                components.append("Host: \(hostStr)")
            }
        }

        // Format key pair fields
        for keyPair in customFields.keyPairs {
            if let publicKey = keyPair.publicKey {
                components.append("Public Key: \(publicKey)")
            }
            if let privateKey = keyPair.privateKey {
                components.append("Private Key: \(privateKey)")
            }
        }

        // Format bank account fields
        for bankAccount in customFields.bankAccounts {
            if let accountType = bankAccount.accountType {
                components.append("Account Type: \(accountType)")
            }
            if let accountNumber = bankAccount.accountNumber {
                components.append("Account Number: \(accountNumber)")
            }
            if let routingNumber = bankAccount.routingNumber {
                components.append("Routing Number: \(routingNumber)")
            }
        }

        // Format security questions
        for sq in customFields.securityQuestions {
            if let question = sq.question {
                components.append("Security Question: \(question)")
            }
            if let answer = sq.answer {
                components.append("Security Answer: \(answer)")
            }
        }

        // Add email fields
        for email in customFields.emails {
            components.append("Email: \(email)")
        }

        // Add note field (unless excluded)
        if !excludeNote, let note = customFields.note {
            components.append("Note: \(note)")
        }

        // Add license number
        if let license = customFields.licenseNumber {
            components.append("License Number: \(license)")
        }

        // Add account numbers
        for accountNumber in customFields.accountNumbers {
            components.append("Account Number: \(accountNumber)")
        }

        // Add secret fields
        for secret in customFields.secrets {
            components.append("Secret: \(secret)")
        }

        // Format payment card
        if let card = customFields.paymentCard {
            if let cardNumber = card.cardNumber {
                components.append("Card Number: \(cardNumber)")
            }
            if let expiration = card.cardExpirationDate {
                components.append("Expiration Date: \(expiration)")
            }
            if let securityCode = card.cardSecurityCode {
                components.append("Security Code: \(securityCode)")
            }
        }

        // Add cardholder name
        if let cardholderName = customFields.cardholderName {
            components.append("Cardholder Name: \(cardholderName)")
        }

        // Add PIN code
        if let pinCode = customFields.pinCode {
            components.append("PIN: \(pinCode)")
        }

        // Add one-time codes (OTP)
        for otpUrl in customFields.oneTimeCodes {
            components.append("One-Time Code: \(otpUrl)")
        }

        // Add URLs
        for url in customFields.urls {
            components.append("URL: \(url)")
        }

        // Add birth dates
        for timestamp in customFields.birthDates {
            let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
            components.append("Birth Date: \(formatDate(date))")
        }

        // Add expiration dates
        for timestamp in customFields.expirationDates {
            let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
            components.append("Expiration Date: \(formatDate(date))")
        }

        // Add generic dates
        for (label, timestamp) in customFields.dates {
            let date = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000)
            let labelStr = label.map { formatDateLabel($0) } ?? "Date"
            components.append("\(labelStr): \(formatDate(date))")
        }

        // Add app fillers
        for appFiller in customFields.appFillers {
            var parts: [String] = []
            if let title = appFiller.applicationTitle, !title.isEmpty {
                parts.append("Application: \(title)")
            }
            if let filter = appFiller.contentFilter, !filter.isEmpty {
                parts.append("Content Filter: \(filter)")
            }
            if let macro = appFiller.macroSequence, !macro.isEmpty {
                parts.append("Macro Sequence: \(macro)")
            }
            if !parts.isEmpty {
                components.append(parts.joined(separator: ", "))
            }
        }

        // Add address references
        for refs in customFields.addressRefs {
            let refStrs = refs.map { String($0) }
            components.append("Address Reference: \(refStrs.joined(separator: ", "))")
        }

        // Add card references
        for refs in customFields.cardRefs {
            let refStrs = refs.map { String($0) }
            components.append("Card Reference: \(refStrs.joined(separator: ", "))")
        }

        return components.isEmpty ? nil : components.joined(separator: "\n")
    }
}

// MARK: - Keeper Format Models

private struct Keeper: Decodable {
    let records: [Record]?

    struct Record: Decodable {
        let uid: Int64?
        let title: String?
        let notes: String?
        let type: String?
        let login: String?
        let password: String?
        let loginUrl: String?
        let folders: [Folder]?
        let customFields: CustomFields?

        enum CodingKeys: String, CodingKey {
            case uid
            case title
            case notes
            case type = "$type"
            case login
            case password
            case loginUrl = "login_url"
            case folders
            case customFields = "custom_fields"
        }
    }

    struct Folder: Decodable {
        let folder: String?
    }

    struct CustomFields: Decodable {
        var names: [NameField] = []
        var addresses: [AddressField] = []
        var phones: [PhoneField] = []
        var hosts: [HostField] = []
        var keyPairs: [KeyPairField] = []
        var bankAccounts: [BankAccountField] = []
        var securityQuestions: [SecurityQuestionField] = []
        var paymentCard: PaymentCardField?
        var cardholderName: String?
        var pinCode: String?
        var textFields: [String] = []
        var emails: [String] = []
        var note: String?
        var licenseNumber: String?
        var accountNumbers: [String] = []
        var secrets: [String] = []
        var multilineFields: [String] = []
        var oneTimeCodes: [String] = []
        var dates: [(label: String?, timestamp: Int64)] = []
        var birthDates: [Int64] = []
        var expirationDates: [Int64] = []
        var urls: [String] = []
        var appFillers: [AppFillerField] = []
        var addressRefs: [[Int64]] = []
        var cardRefs: [[Int64]] = []

        struct NameField: Decodable {
            let first: String?
            let middle: String?
            let last: String?
        }

        struct AddressField: Decodable {
            let street1: String?
            let street2: String?
            let city: String?
            let state: String?
            let zip: String?
            let country: String?
        }

        struct PhoneField: Decodable {
            let region: String?
            let number: String?
            let ext: String?
        }

        struct HostField: Decodable {
            let hostName: String?
            let port: String?
        }

        struct KeyPairField: Decodable {
            let publicKey: String?
            let privateKey: String?
        }

        struct BankAccountField: Decodable {
            let accountType: String?
            let accountNumber: String?
            let routingNumber: String?
            let otherType: String?
        }

        struct SecurityQuestionField: Decodable {
            let question: String?
            let answer: String?
        }

        struct PaymentCardField: Decodable {
            let cardNumber: String?
            let cardExpirationDate: String?
            let cardSecurityCode: String?
        }

        struct AppFillerField: Decodable {
            let applicationTitle: String?
            let contentFilter: String?
            let macroSequence: String?
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: DynamicCodingKey.self)

            for key in container.allKeys {
                let keyString = key.stringValue

                // Parse $name::N fields
                if keyString.hasPrefix("$name::") || keyString == "$name:insuredsName:1" {
                    if let name = try? container.decode(NameField.self, forKey: key) {
                        names.append(name)
                    }
                }
                // Parse $address::N fields
                else if keyString.hasPrefix("$address::") {
                    if let address = try? container.decode(AddressField.self, forKey: key) {
                        addresses.append(address)
                    }
                }
                // Parse $phone::N fields
                else if keyString.hasPrefix("$phone::") {
                    if let phone = try? container.decode(PhoneField.self, forKey: key) {
                        phones.append(phone)
                    }
                }
                // Parse $host::N fields
                else if keyString.hasPrefix("$host::") {
                    if let host = try? container.decode(HostField.self, forKey: key) {
                        hosts.append(host)
                    }
                }
                // Parse $keyPair::N fields
                else if keyString.hasPrefix("$keyPair::") {
                    if let keyPair = try? container.decode(KeyPairField.self, forKey: key) {
                        keyPairs.append(keyPair)
                    }
                }
                // Parse $bankAccount::N fields
                else if keyString.hasPrefix("$bankAccount::") {
                    if let bankAccount = try? container.decode(BankAccountField.self, forKey: key) {
                        bankAccounts.append(bankAccount)
                    }
                }
                // Parse $securityQuestion::N fields
                else if keyString.hasPrefix("$securityQuestion::") {
                    if let sq = try? container.decode(SecurityQuestionField.self, forKey: key) {
                        securityQuestions.append(sq)
                    }
                }
                // Parse $paymentCard::N fields
                else if keyString.hasPrefix("$paymentCard::") {
                    if let card = try? container.decode(PaymentCardField.self, forKey: key) {
                        paymentCard = card
                    }
                }
                // Parse $text:cardholderName:N fields
                else if keyString.contains(":cardholderName:") {
                    if let value = try? container.decode(String.self, forKey: key) {
                        cardholderName = value
                    }
                }
                // Parse $pinCode::N fields
                else if keyString.hasPrefix("$pinCode::") {
                    if let value = try? container.decode(String.self, forKey: key) {
                        pinCode = value
                    }
                }
                // Parse $text::N and $text:type:N fields (simple text)
                else if keyString.hasPrefix("$text::") || keyString.hasPrefix("$text:") {
                    if let value = try? container.decode(String.self, forKey: key) {
                        textFields.append(value)
                    }
                }
                // Parse $email::N fields
                else if keyString.hasPrefix("$email::") {
                    if let value = try? container.decode(String.self, forKey: key) {
                        emails.append(value)
                    }
                }
                // Parse $note::N fields
                else if keyString.hasPrefix("$note::") {
                    if let value = try? container.decode(String.self, forKey: key) {
                        note = value
                    }
                }
                // Parse $licenseNumber::N fields
                else if keyString.hasPrefix("$licenseNumber::") {
                    if let value = try? container.decode(String.self, forKey: key) {
                        licenseNumber = value
                    }
                }
                // Parse $accountNumber::N and $accountNumber:*:N fields
                else if keyString.hasPrefix("$accountNumber") {
                    if let value = try? container.decode(String.self, forKey: key) {
                        accountNumbers.append(value)
                    }
                }
                // Parse $secret::N fields
                else if keyString.hasPrefix("$secret::") {
                    if let value = try? container.decode(String.self, forKey: key) {
                        secrets.append(value)
                    }
                }
                // Parse $multiline::N fields
                else if keyString.hasPrefix("$multiline::") {
                    if let value = try? container.decode(String.self, forKey: key) {
                        multilineFields.append(value)
                    }
                }
                // Parse plain text custom fields (no $ prefix, not "references")
                else if !keyString.hasPrefix("$") && keyString != "references" {
                    if let value = try? container.decode(String.self, forKey: key) {
                        textFields.append("\(keyString): \(value)")
                    }
                }
                // Parse $oneTimeCode::N or $oneTimeCode fields (OTP URLs)
                else if keyString.hasPrefix("$oneTimeCode") {
                    if let value = try? container.decode(String.self, forKey: key) {
                        oneTimeCodes.append(value)
                    }
                }
                // Parse $url::N fields
                else if keyString.hasPrefix("$url::") {
                    if let value = try? container.decode(String.self, forKey: key) {
                        urls.append(value)
                    }
                }
                // Parse $birthDate::N fields (timestamp in milliseconds)
                else if keyString.hasPrefix("$birthDate::") {
                    if let value = try? container.decode(Int64.self, forKey: key) {
                        birthDates.append(value)
                    }
                }
                // Parse $expirationDate::N fields (timestamp in milliseconds)
                else if keyString.hasPrefix("$expirationDate::") {
                    if let value = try? container.decode(Int64.self, forKey: key) {
                        expirationDates.append(value)
                    }
                }
                // Parse $date::N and $date:type:N fields (timestamp in milliseconds)
                else if keyString.hasPrefix("$date") {
                    if let value = try? container.decode(Int64.self, forKey: key) {
                        // Extract label from key like "$date:dateActive:1" -> "dateActive"
                        let label: String? = {
                            let parts = keyString.split(separator: ":")
                            if parts.count >= 2 {
                                let potentialLabel = String(parts[1])
                                if potentialLabel != "" && !potentialLabel.allSatisfy({ $0.isNumber }) {
                                    return potentialLabel
                                }
                            }
                            return nil
                        }()
                        dates.append((label: label, timestamp: value))
                    }
                }
                // Parse $appFiller::N fields
                else if keyString.hasPrefix("$appFiller::") {
                    if let appFiller = try? container.decode(AppFillerField.self, forKey: key) {
                        appFillers.append(appFiller)
                    }
                }
                // Parse references object containing $addressRef and $cardRef
                else if keyString == "references" {
                    if let refs = try? container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: key) {
                        for refKey in refs.allKeys {
                            let refKeyString = refKey.stringValue
                            if refKeyString.hasPrefix("$addressRef") {
                                if let refIds = try? refs.decode([Int64].self, forKey: refKey) {
                                    addressRefs.append(refIds)
                                }
                            } else if refKeyString.hasPrefix("$cardRef") {
                                if let refIds = try? refs.decode([Int64].self, forKey: refKey) {
                                    cardRefs.append(refIds)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    struct DynamicCodingKey: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }

        init?(intValue: Int) {
            self.stringValue = String(intValue)
            self.intValue = intValue
        }
    }
}
