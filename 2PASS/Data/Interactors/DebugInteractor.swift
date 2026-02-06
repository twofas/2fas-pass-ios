// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public protocol DebugInteracting: AnyObject {
    // MARK: - Has value
    var hasDeviceID: Bool { get }
    var hasSelectedVault: Bool { get }
    var isInMemoryStorageActive: Bool { get }
    var hasStoredMasterKey: Bool { get }
    var hasBiometryKey: Bool { get }
    var hasAppKey: Bool { get }
    var hasSeed: Bool { get }
    var hasInMemoryEntropy: Bool { get }
    var hasWords: Bool { get }
    var hasSalt: Bool { get }
    var hasMasterPassword: Bool { get }
    var hasInMemoryMasterKey: Bool { get }
    var hasEncryptionReference: Bool { get }
    var hasStoredEntropy: Bool { get }
    var hasTrustedKey: Bool { get }
    var hasSecureKey: Bool { get }
    var hasExternalKey: Bool { get }
    
    // MARK: - Value
    
    var deviceID: DeviceID? { get }
    var selectedVaultID: VaultID? { get }
    var storedMasterKey: MasterKey? { get }
    var seed: Seed? { get }
    var inMemoryEntropy: Entropy? { get }
    var words: [String]? { get }
    var salt: Data? { get }
    var masterPassword: MasterPassword? { get }
    var inMemoryMasterKey: MasterKey? { get }
    var storedEntropy: Entropy? { get }
    var trustedKey: TrustedKey? { get }
    var secureKey: SecureKey? { get }
    var externalKey: ExternalKey? { get }
    
    // MARK: - Clear values
    
    func clearDeviceID()
    func deleteVault()
    func clearAppKey()
    func clearBiometryKey()
    func clearStoredMasterKey()
    func clearEncryptionReference()
    func clearStoredEntropy()
    func randomizeAppKey()
    func reboot()
    
    // MARK: - Logs
    func listAllLogEntries() -> [LogEntry]
    func clearAllLogs()
    func generateLogs() -> String
    
    // MARK: - Items
    var itemsCount: Int { get }
    func deleteAllItems()
    func generateItems(count: Int, completion: @escaping Callback)

    var secureNotesCount: Int { get }
    func generateSecureNotes(count: Int, completion: @escaping Callback)

    var unknownCount: Int { get }
    func generateUnknown(count: Int, completion: @escaping Callback)
    var paymentCardsCount: Int { get }
    func generatePaymentCards(count: Int, completion: @escaping Callback)

    var tagsCount: Int { get }
    func deleteAllTags()

    // MARK: - WebDAV debug
    var writeDecryptedCopy: Bool { get }
    func setWriteDecryptedCopy(_ writeDecryptedCopy: Bool)
    
    // MARK: - Payment Status
    var isOverridedSubscriptionPlan: Bool { get }
    var subscriptionPlan: SubscriptionPlan { get }
    func overrideSubscriptionPlan(_ plan: SubscriptionPlan)
    func clearOverrideSubscriptionPlan()
}

final class DebugInteractor {
    private let mainRepository: MainRepository
    private let itemsInteractor: ItemsInteracting
    private let loginItemInteractor: LoginItemInteracting
    private let paymentCardItemInteractor: PaymentCardItemInteracting
    private let secureNoteItemInteractor: SecureNoteItemInteracting

    init(
        mainRepository: MainRepository,
        itemsInteractor: ItemsInteracting,
        loginItemInteractor: LoginItemInteracting,
        paymentCardItemInteractor: PaymentCardItemInteracting,
        secureNoteItemInteractor: SecureNoteItemInteracting
    ) {
        self.mainRepository = mainRepository
        self.itemsInteractor = itemsInteractor
        self.loginItemInteractor = loginItemInteractor
        self.paymentCardItemInteractor = paymentCardItemInteractor
        self.secureNoteItemInteractor = secureNoteItemInteractor
    }
}

extension DebugInteractor: DebugInteracting {
    // MARK: - Has value
    
    var hasDeviceID: Bool {
        mainRepository.deviceID != nil
    }
    
    var hasSelectedVault: Bool {
        selectedVaultID != nil
    }
    
    var isInMemoryStorageActive: Bool {
        mainRepository.hasInMemoryStorage
    }
    
    var hasStoredMasterKey: Bool {
        storedMasterKey != nil
    }
    
    var hasBiometryKey: Bool {
        mainRepository.biometryKey != nil
    }
    
    var hasAppKey: Bool {
        mainRepository.appKey != nil
    }
    
    var hasSeed: Bool {
        seed != nil
    }
    
    var hasInMemoryEntropy: Bool {
        inMemoryEntropy != nil
    }
    
    var hasWords: Bool {
        words != nil && words?.isEmpty == false
    }
    
    var hasSalt: Bool {
        salt != nil
    }
    
    var hasMasterPassword: Bool {
        masterPassword != nil
    }
    
    var hasInMemoryMasterKey: Bool {
        inMemoryMasterKey != nil
    }
    
    var hasEncryptionReference: Bool {
        mainRepository.hasEncryptionReference
    }
    
    var hasStoredEntropy: Bool {
        mainRepository.hasMasterKeyEntropy
    }
    
    var hasTrustedKey: Bool {
        trustedKey != nil
    }
    
    var hasSecureKey: Bool {
        secureKey != nil
    }
    
    var hasExternalKey: Bool {
        externalKey != nil
    }
    
    // MARK: - Value
    
    var deviceID: DeviceID? {
        mainRepository.deviceID
    }
    
    var selectedVaultID: VaultID? {
        mainRepository.selectedVault?.vaultID
    }
    
    var storedMasterKey: MasterKey? {
        mainRepository.decryptStoredMasterKey()
    }
    
    var seed: Seed? {
        mainRepository.seed
    }
    
    var inMemoryEntropy: Entropy? {
        mainRepository.entropy
    }
    
    var words: [String]? {
        mainRepository.words
    }
    
    var salt: Data? {
        mainRepository.salt
    }
    
    var masterPassword: MasterPassword? {
        mainRepository.masterPassword
    }
    
    var inMemoryMasterKey: MasterKey? {
        mainRepository.empheralMasterKey
    }
    
    var storedEntropy: Entropy? {
        mainRepository.masterKeyEntropy
    }
    
    var trustedKey: TrustedKey? {
        mainRepository.trustedKey
    }
    
    var secureKey: SecureKey? {
        mainRepository.secureKey
    }
    
    var externalKey: ExternalKey? {
        mainRepository.externalKey
    }
    
    // MARK: - Clear values
    
    func clearDeviceID() {
        mainRepository.clearDeviceID()
    }
    
    func deleteVault() {
        guard let selectedVaultID else { return }
        mainRepository.deleteEncryptedVault(selectedVaultID)
    }

    func clearAppKey() {
        mainRepository.clearAppKey()
    }

    func clearBiometryKey() {
        mainRepository.clearBiometryKey()
    }
    
    func clearStoredMasterKey() {
        mainRepository.clearMasterKey()
    }
    
    func clearEncryptionReference() {
        mainRepository.clearEncryptionReference()
    }

    func clearStoredEntropy() {
        mainRepository.clearMasterKeyEntropy()
    }
    
    func randomizeAppKey() {
        mainRepository.saveAppKey(UUID().uuidString.data(using: .utf8)!)
    }
    
    func reboot() {
        abort()
    }
        
    // MARK: - Logs
    
    func listAllLogEntries() -> [LogEntry] {
        mainRepository.listAllLogs()
    }
    
    func clearAllLogs() {
        mainRepository.removeAllLogs()
    }
    
    func generateLogs() -> String {
        var output = """
        Bundle: \(mainRepository.appBundleIdentifier ?? "")
        Version: \(mainRepository.currentAppVersion) (\(mainRepository.currentBuildVersion))
        OS: \(mainRepository.systemVersion)
        Device: \(mainRepository.deviceModelName)
        
        DeviceID: \(hasDeviceID)
        SelectedVault: \(hasSelectedVault)
        InMemoryStorageActive: \(isInMemoryStorageActive)
        StoredMasterKey: \(hasStoredMasterKey)
        BiometryKey: \(hasBiometryKey)
        Seed: \(hasSeed)
        InMemoryEntropy: \(hasInMemoryEntropy)
        Words: \(hasWords)
        Salt: \(hasSalt)
        MasterPassword: \(hasMasterPassword)
        InMemoryMasterKey: \(hasInMemoryMasterKey)
        EncryptionReference: \(hasEncryptionReference)
        StoredEntropy: \(hasStoredEntropy)
        TrustedKey: \(hasTrustedKey)
        SecureKey: \(hasSecureKey)
        ExternalKey: \(hasExternalKey)
        """
        
        output += "\n\n"
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let logs = mainRepository.listAllLogs().map {
            var entry = "\(dateFormatter.string(from: $0.timestamp)) \($0.module): "
            if $0.severity != .unknown {
                entry.append("[\($0.severity)] ")
            }
            entry.append($0.content)
            return entry
        }
        .joined(separator: "\n")
        
        return output + logs
    }
    
    // MARK: - Items
    
    var itemsCount: Int {
        mainRepository.listItems(options: .allNotTrashed).count
    }
    
    var secureNotesCount: Int {
        mainRepository.listItems(options: .allNotTrashed)
            .filter { $0.contentType == .secureNote }
            .count
    }

    var unknownCount: Int {
        mainRepository.listItems(options: .allNotTrashed)
            .filter {
                if case .unknown = $0.contentType {
                    return true
                }
                return false
            }
            .count
    }

    var paymentCardsCount: Int {
        mainRepository.listItems(options: .allNotTrashed)
            .filter { $0.contentType == .paymentCard }
            .count
    }
    
    func deleteAllItems() {
        mainRepository.deleteAllItems()
        mainRepository.deleteAllEncryptedItems()
        mainRepository.saveStorage()
        mainRepository.saveEncryptedStorage()
        mainRepository.webDAVSetHasLocalChanges()
    }
    
    func generateItems(count: Int, completion: @escaping Callback) {
        guard let words = mainRepository.importBIP0039Words() else {
            completion()
            return
        }

        for i in 0..<count {
            let name = words.randomElement() ?? "Test\(i)"
            let username = "\(words.randomElement() ?? "one")\(i)@\(words.randomElement() ?? "second").com"
            let uri = "\(words.randomElement() ?? "second").com"
            let password = words.randomElement() ?? "SomePass123\(i)"
            let notes = Array(repeating: "", count: Int.random(in: 5..<100)).compactMap({ _ in words.randomElement() }).joined(separator: " ")
            let date = randomDate()

            try? loginItemInteractor.createLogin(
                id: .init(),
                metadata: .init(
                    creationDate: date,
                    modificationDate: date,
                    protectionLevel: [ItemProtectionLevel.confirm,
                                      ItemProtectionLevel.normal,
                                      ItemProtectionLevel.topSecret].randomElement() ?? .normal,
                    trashedStatus: .no,
                    tagIds: randomTagIds()
                ),
                name: name,
                username: username,
                password: password,
                notes: notes,
                iconType: .domainIcon(uri),
                uris: [.init(uri: uri,
                match: .domain),
                .init(uri: name,
                match: .exact),
                .init(uri: password,
                match: .startsWith)],
            )
        }

        itemsInteractor.saveStorage()
        mainRepository.webDAVSetHasLocalChanges()
        completion()
    }
    
    func generateSecureNotes(count: Int, completion: @escaping Callback) {
        guard let words = mainRepository.importBIP0039Words() else {
            completion()
            return
        }

        for i in 0..<count {
            let name = words.randomElement() ?? "Note\(i)"
            let text = Array(repeating: "", count: Int.random(in: 10..<150)).compactMap({ _ in words.randomElement() }).joined(separator: " ")
            let date = randomDate()

            try? secureNoteItemInteractor.createSecureNote(
                id: .init(),
                metadata: .init(
                    creationDate: date,
                    modificationDate: date,
                    protectionLevel: [ItemProtectionLevel.confirm,
                                      ItemProtectionLevel.normal,
                                      ItemProtectionLevel.topSecret].randomElement() ?? .normal,
                    trashedStatus: .no,
                    tagIds: randomTagIds()
                ),
                name: name,
                text: text,
                additionalInfo: Bool.random() ? "Additional info for note \(i)" : nil
            )
        }

        itemsInteractor.saveStorage()
        mainRepository.webDAVSetHasLocalChanges()
        completion()
    }

    func generateUnknown(count: Int, completion: @escaping Callback) {
        guard let words = mainRepository.importBIP0039Words(),
              let vaultId = selectedVaultID else {
            completion()
            return
        }

        for i in 0..<count {
            let protectionLevel = [ItemProtectionLevel.confirm,
                                   ItemProtectionLevel.normal,
                                   ItemProtectionLevel.topSecret].randomElement() ?? .normal
            let name = words.randomElement() ?? "Unknown\(i)"
            let contentDict: [String: Any] = [
                "field1": words.randomElement() ?? "value1",
                "s_field2": itemsInteractor.encrypt(words.randomElement() ?? "value2", isSecureField: true, protectionLevel: protectionLevel)!.base64EncodedString()
            ]

            guard let contentData = try? JSONEncoder().encode(AnyCodable(contentDict)) else { continue }

            let date = randomDate()
            let rawItem = RawItemData(
                id: .init(),
                vaultId: vaultId,
                metadata: .init(
                    creationDate: date,
                    modificationDate: date,
                    protectionLevel: protectionLevel,
                    trashedStatus: .no,
                    tagIds: randomTagIds()
                ),
                name: name,
                contentType: .unknown("customType"),
                contentVersion: 1,
                content: contentData
            )
            try? itemsInteractor.createItem(.raw(rawItem))
        }

        itemsInteractor.saveStorage()
        mainRepository.webDAVSetHasLocalChanges()
        completion()
    }

    func generatePaymentCards(count: Int, completion: @escaping Callback) {
        guard let words = mainRepository.importBIP0039Words() else {
            completion()
            return
        }

        for i in 0..<count {
            let date = randomDate()
            let protectionLevel = [ItemProtectionLevel.confirm,
                                   ItemProtectionLevel.normal,
                                   ItemProtectionLevel.topSecret].randomElement() ?? .normal
            let tags = randomTagIds()
            let cardData = randomPaymentCardData()
            let name = "\(words.randomElement()?.capitalizedFirstLetter ?? "") Card"
            let cardHolder = "John Doe \(i)"
            let month = String(format: "%02d", Int.random(in: 1...12))
            let year = String(format: "%02d", Int.random(in: 26...36))
            let expirationDate = "\(month)/\(year)"

            try? paymentCardItemInteractor.createPaymentCard(
                id: .init(),
                metadata: .init(
                    creationDate: date,
                    modificationDate: date,
                    protectionLevel: protectionLevel,
                    trashedStatus: .no,
                    tagIds: tags
                ),
                name: name,
                cardHolder: cardHolder,
                cardNumber: cardData.number,
                expirationDate: expirationDate,
                securityCode: cardData.securityCode,
                notes: nil
            )
        }

        itemsInteractor.saveStorage()
        mainRepository.webDAVSetHasLocalChanges()
        completion()
    }

    var tagsCount: Int {
        mainRepository.listTags(options: .all).count
    }

    func deleteAllTags() {
        mainRepository.deleteAllTags()
        mainRepository.deleteAllEncryptedTags()
        mainRepository.saveStorage()
        mainRepository.saveEncryptedStorage()
        mainRepository.webDAVSetHasLocalChanges()
    }

    // MARK: - WebDAV debug
    
    var writeDecryptedCopy: Bool {
        mainRepository.webDAVWriteDecryptedCopy
    }
    
    func setWriteDecryptedCopy(_ writeDecryptedCopy: Bool) {
        mainRepository.webDAVSetWriteDecryptedCopy(writeDecryptedCopy)
    }
    
    // MARK: - Payment Status
    
    var isOverridedSubscriptionPlan: Bool {
        mainRepository.isOverridedSubscriptionPlan
    }
    var subscriptionPlan: SubscriptionPlan {
        mainRepository.paymentSubscriptionPlan
    }
    
    func overrideSubscriptionPlan(_ plan: SubscriptionPlan) {
        mainRepository.overrideSubscriptionPlan(plan)
    }
    
    func clearOverrideSubscriptionPlan() {
        mainRepository.clearOverrideSubscriptionPlan()
    }
}
private extension DebugInteractor {
    
    func randomTagIds() -> [ItemTagID]? {
        let allTags = mainRepository.listTags(options: .all)
        return randomTagIds(from: allTags)
    }
    
    func randomTagIds(from allTags: [ItemTagData], maxCount: Int = 3) -> [ItemTagID]? {
        guard !allTags.isEmpty else { return nil }
        let tagCount = Int.random(in: 0...min(maxCount, allTags.count))
        guard tagCount > 0 else { return nil }
        return Array(allTags.shuffled().prefix(tagCount).map { $0.tagID })
    }

    func randomDate() -> Date {
        let date = mainRepository.currentDate
        let calendar = Calendar.current
        var dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        dateComponents.setValue(-1, for: .month)
        
        guard
            let newDate = calendar.date(from: dateComponents),
            let days = calendar.range(of: .day, in: .month, for: newDate),
            let randomDay = days.randomElement()
        else {
            return mainRepository.currentDate
        }
        dateComponents.setValue(randomDay, for: .day)
        return calendar.date(from: dateComponents) ?? mainRepository.currentDate
    }

    func randomPaymentCardData() -> (number: String, securityCode: String) {
        enum IssuerVariant {
            case known(PaymentCardIssuer)
            case unknown
        }

        struct CardFormat {
            let prefix: String
            let numberLength: Int
            let securityCodeLength: Int
        }

        let variants: [IssuerVariant] = PaymentCardIssuer.allCases.map { .known($0) } + [.unknown]
        let selectedVariant = variants.randomElement() ?? .known(.visa)
        let format: CardFormat = {
            switch selectedVariant {
            case .known(.visa):
                return .init(prefix: "4", numberLength: 16, securityCodeLength: 3)
            case .known(.mastercard):
                return .init(prefix: Bool.random() ? "55" : "2221", numberLength: 16, securityCodeLength: 3)
            case .known(.americanExpress):
                return .init(prefix: Bool.random() ? "34" : "37", numberLength: 15, securityCodeLength: 4)
            case .known(.discover):
                return .init(prefix: ["6011", "65", "644"].randomElement() ?? "6011", numberLength: 16, securityCodeLength: 3)
            case .known(.dinersClub):
                return .init(prefix: ["36", "38", "300"].randomElement() ?? "36", numberLength: 14, securityCodeLength: 3)
            case .known(.jcb):
                return .init(prefix: "3528", numberLength: 16, securityCodeLength: 3)
            case .known(.unionPay):
                return .init(prefix: "62", numberLength: 16, securityCodeLength: 3)
            case .unknown:
                // Deliberately avoid known BIN ranges so issuer detection can return nil.
                return .init(prefix: "90", numberLength: 16, securityCodeLength: 3)
            }
        }()

        let payloadLength = max(0, format.numberLength - format.prefix.count - 1)
        let payload = (0..<payloadLength).map { _ in String(Int.random(in: 0...9)) }.joined()
        let baseNumber = format.prefix + payload
        let checkDigit = luhnCheckDigit(for: baseNumber)
        let number = baseNumber + String(checkDigit)
        let securityCode = (0..<format.securityCodeLength).map { _ in String(Int.random(in: 0...9)) }.joined()

        return (number: number, securityCode: securityCode)
    }

    func luhnCheckDigit(for numberWithoutCheckDigit: String) -> Int {
        let digits = numberWithoutCheckDigit.compactMap(\.wholeNumberValue)
        guard digits.count == numberWithoutCheckDigit.count else { return 0 }

        let sum = digits.reversed().enumerated().reduce(into: 0) { partialResult, element in
            let index = element.offset
            let digit = element.element

            if index.isMultiple(of: 2) {
                let doubled = digit * 2
                partialResult += doubled > 9 ? doubled - 9 : doubled
            } else {
                partialResult += digit
            }
        }

        return (10 - (sum % 10)) % 10
    }
}
