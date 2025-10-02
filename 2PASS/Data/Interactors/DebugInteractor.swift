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
    
    // MARK: - Passwords
    var passwordCount: Int { get }
    func deleteAllPasswords()
    func generatePasswords(count: Int, completion: @escaping Callback)
    
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
    private let passwordInteractor: PasswordInteracting
    
    init(mainRepository: MainRepository, passwordInteractor: PasswordInteracting) {
        self.mainRepository = mainRepository
        self.passwordInteractor = passwordInteractor
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
    
    // MARK: - Passwords
    
    var passwordCount: Int {
        mainRepository.listPasswords(options: .allNotTrashed).count
    }
    
    func deleteAllPasswords() {
        mainRepository.deleteAllPasswords()
        mainRepository.deleteAllEncryptedItems()
        mainRepository.saveStorage()
        mainRepository.saveEncryptedStorage()
        mainRepository.webDAVSetHasLocalChanges()
    }
    
    func generatePasswords(count: Int, completion: @escaping Callback) {
        guard let words = mainRepository.importBIP0039Words() else {
            completion()
            return
        }
        
        for i in 0..<count {
            let name = words.randomElement() ?? "Test\(i)"
            let username = "\(words.randomElement() ?? "one")\(i)@\(words.randomElement() ?? "second").com"
            let password = words.randomElement() ?? "SomePass123\(i)"
            let notes = Array(repeating: "", count: Int.random(in: 5..<100)).compactMap({ _ in words.randomElement() }).joined(separator: " ")
            let date = randomDate()
            _ = passwordInteractor.createPassword(
                passwordID: .init(),
                name: name,
                username: username,
                password: password,
                notes: notes,
                creationDate: date,
                modificationDate: date,
                iconType: .default,
                trashedStatus: .no,
                protectionLevel: [ItemProtectionLevel.confirm,
                ItemProtectionLevel.normal,
                ItemProtectionLevel.topSecret].randomElement() ?? .normal,
                uris: [.init(uri: username,
                match: .domain),
                .init(uri: name,
                match: .exact),
                .init(uri: password,
                match: .startsWith)],
                tagIds: nil
            )
        }

        passwordInteractor.saveStorage()
        mainRepository.webDAVSetHasLocalChanges()
        completion()
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
}
