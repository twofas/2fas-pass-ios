// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common
import CryptoKit

public enum ImportOpenFileError: Error {
    case cantReadFile(reason: String?)
}

public enum ImportParseError: Error {
    case jsonError(Error)
    case schemaNotSupported(Int)
    case nothingToImport
}

public enum ImportEncryptionType {
    case noEncryption
    case noExternalKeyError
    case noSelectedVaultError
    case missingEncryptionError
    case passwordChanged
    case currentEncryption
    case needsPasswordWords
}

public enum ImportEncryptionTypeNoParsing {
    case noEncryption
    case needsPassword
}

public enum ImportExtractCurrentEncryptionError: Error {
    case noExternalKey
    case noPasswordsField
    case noVaultID
}

public enum ImportExtractMasterPasswordEncryptionError: Error {
    case incorrectVaultID
    case masterKey
    case symmetricalKey
    case noReference
    case decryptingReference
    case referenceMismatch
    case noPasswords
}

public enum ImportExtractMasterPasswordReferenceVerificationError: Error {
    case masterKey
    case symmetricalKey
    case noReference
    case decryptingReference
    case referenceMismatch
}

public protocol ImportInteracting: AnyObject {
    func openFile(url: URL, completion: @escaping (Result<Data, ImportOpenFileError>) -> Void)
    func parseContents(of data: Data, completion: @escaping (Result<ExchangeVault, ImportParseError>) -> Void)
    func checkDeviceId(in vault: ExchangeVault) -> Bool
    func checkEncryption(in vault: ExchangeVault) -> ImportEncryptionType
    func checkEncryptionWithoutParsing(in vault: ExchangeVault) -> ImportEncryptionTypeNoParsing
    func extractPasswordsUsingCurrentEncryption(
        from vault: ExchangeVault,
        completion: @escaping (Result<([PasswordData], [ItemTagData], [DeletedItemData]), ImportExtractCurrentEncryptionError>) -> Void
    )
    func extractUnencryptedPasswords(from file: ExchangeVault) -> [PasswordData]
    func extractUnencryptedTags(from file: ExchangeVault) -> [ItemTagData]
    
    func extractPasswordsUsingMasterPassword(
        _ masterPassword: MasterPassword,
        words: [String],
        vault: ExchangeVault,
        completion: @escaping (Result<([PasswordData], [ItemTagData], [DeletedItemData]), ImportExtractMasterPasswordEncryptionError>) -> Void
    )
    func extractPasswordsUsingMasterKey(
        _ masterKey: MasterKey,
        exchangeVault: ExchangeVault,
        completion: @escaping (Result<([PasswordData], [ItemTagData], [DeletedItemData]), ImportExtractMasterPasswordEncryptionError>) -> Void
    )
    func extractUnencryptedDeletedItems(from file: ExchangeVault) -> [DeletedItemData]
    func validateWords(_ words: [String], using seedHash: String, vaultID: VaultID) -> Bool
    func validateReference(
        _ reference: String,
        using masterKey: MasterKey,
        for vaultID: VaultID
    ) -> Result<SymmetricKey, ImportExtractMasterPasswordReferenceVerificationError>
    func isVaultReadyForImport() -> Bool
    func scan(image: UIImage, completion: @escaping VisionScanCompletion)
    func generateSeedHash(from entropy: Entropy, vaultID: VaultID) -> String?
}

final class ImportInteractor {
    private let mainRepository: MainRepository
    private let passwordInteractor: PasswordInteracting
    private let protectionInteractor: ProtectionInteracting
    private let uriInteractor: URIInteracting
    private let queue: DispatchQueue
    private let writeQueue: DispatchQueue
    
    init(
        mainRepository: MainRepository,
        passwordInteractor: PasswordInteracting,
        protectionInteractor: ProtectionInteracting,
        uriInteractor: URIInteracting
    ) {
        self.mainRepository = mainRepository
        self.passwordInteractor = passwordInteractor
        self.protectionInteractor = protectionInteractor
        self.uriInteractor = uriInteractor
        self.queue = DispatchQueue(label: "ImportQueue", qos: .userInteractive, attributes: .concurrent)
        self.writeQueue = DispatchQueue(label: "ExportWriteArray", qos: .userInitiated)
    }
}

extension ImportInteractor: ImportInteracting {
    func openFile(url: URL, completion: @escaping (Result<Data, ImportOpenFileError>) -> Void) {
        do {
            var data: Data?
            if url.startAccessingSecurityScopedResource() {
                var error: NSError?
                NSFileCoordinator().coordinate(readingItemAt: url, options: [.withoutChanges], error: &error) { url in
                    do {
                        data = try Data(contentsOf: url)
                    } catch {
                        url.stopAccessingSecurityScopedResource()
                        completion(.failure(.cantReadFile(reason: error.localizedDescription)))
                        return
                    }
                }
                url.stopAccessingSecurityScopedResource()
            } else {
                data = try Data(contentsOf: url)
            }
            
            guard let data else {
                completion(.failure(.cantReadFile(reason: nil)))
                return
            }
            
            completion(.success(data))
        } catch {
            Log("Can't import data from file: \(url), error: \(error)")
            completion(.failure(.cantReadFile(reason: error.localizedDescription)))
            return
        }
    }
    
    func parseContents(of data: Data, completion: @escaping (Result<ExchangeVault, ImportParseError>) -> Void) {
        func end(_ result: Result<ExchangeVault, ImportParseError>) {
            DispatchQueue.main.async {
                completion(result)
            }
        }
        queue.async {
            let jsonDecoder = self.mainRepository.jsonDecoder
            do {
                let parsedJSON = try jsonDecoder.decode(ExchangeVault.self, from: data)
                end(.success(parsedJSON))
            } catch let ExchangeError.mismatchSchemaVersion(actualVersion, expected: expectedVersion) {
                end(.failure(.schemaNotSupported(actualVersion)))
            } catch {
                end(.failure(.jsonError(error)))
            }
        }
    }
    
    func checkDeviceId(in vault: ExchangeVault) -> Bool {
        mainRepository.deviceID == vault.origin.deviceId
    }
    
    func checkEncryption(in file: ExchangeVault) -> ImportEncryptionType {
        if let logins = file.vault.logins, !logins.isEmpty {
            return .noEncryption
        }
        guard let key = mainRepository.cachedExternalKey else {
            return .noExternalKeyError
        }
        guard let selectedVault = mainRepository.selectedVault else {
            return .noSelectedVaultError
        }
        guard let encryption = file.encryption, let data = Data(base64Encoded: encryption.reference) else {
            return .missingEncryptionError
        }
        guard let reference = mainRepository.decrypt(data, key: key),
              let string = String(data: reference, encoding: .utf8),
              UUID(uuidString: string) == selectedVault.vaultID
        else {
            if encryption.seedHash == mainRepository.createSeedHashHexForExport() {
                return .passwordChanged
            } else {
                return .needsPasswordWords
            }
        }
        return .currentEncryption
    }
    
    func extractUnencryptedPasswords(from file: ExchangeVault) -> [PasswordData] {
        guard let logins = file.vault.logins else {
            return []
        }
        return logins.compactMap({ self.exchangeLoginToPasswordData($0) })
    }
    
    func extractUnencryptedDeletedItems(from file: ExchangeVault) -> [DeletedItemData] {
        guard let loginsDeleted = file.vault.itemsDeleted, let vaultID = UUID(uuidString: file.vault.id) else {
            return []
        }
        return loginsDeleted.compactMap({ self.exchangeDeletedPasswordToDeletedPasswordData($0, vaultID: vaultID) })
    }
    
    func extractUnencryptedTags(from file: ExchangeVault) -> [ItemTagData] {
        guard let tags = file.vault.tags, let vaultID = mainRepository.selectedVault?.vaultID else {
            return []
        }
        return tags.compactMap({ self.exchangeTagToItemTagData($0, vaultID: vaultID) })
    }
    
    func checkEncryptionWithoutParsing(in vault: ExchangeVault) -> ImportEncryptionTypeNoParsing {
        if vault.vault.logins?.isEmpty == false {
            return .noEncryption
        }
        return .needsPassword
    }
    
    func extractPasswordsUsingCurrentEncryption(
        from vault: ExchangeVault,
        completion: @escaping (Result<([PasswordData], [ItemTagData], [DeletedItemData]), ImportExtractCurrentEncryptionError>) -> Void
    ) {
        guard let passwords = vault.vault.loginsEncrypted else {
            completion(.failure(.noPasswordsField))
            return
        }
        guard let key = mainRepository.cachedExternalKey else {
            completion(.failure(.noExternalKey))
            return
        }
        
        guard let vaultID = UUID(uuidString: vault.vault.id) else {
            completion(.failure(.noVaultID))
            return
        }
        
        let deletedPasswords = vault.vault.itemsDeletedEncrypted ?? []
        let tags = vault.vault.tagsEncrypted ?? []
        
        extractPasswords(from: passwords, tags: tags, deletedPasswords: deletedPasswords, vaultID: vaultID, using: key) { passwordsData, tagsData, deletedData in
            completion(.success((passwordsData, tagsData, deletedData)))
        }
    }
    
    func extractPasswordsUsingMasterPassword(
        _ masterPassword: MasterPassword,
        words: [String],
        vault: ExchangeVault,
        completion: @escaping (Result<([PasswordData], [ItemTagData], [DeletedItemData]), ImportExtractMasterPasswordEncryptionError>) -> Void
    ) {
        let kdfSpec: KDFSpec = {
            guard let spec = vault.encryption?.kdfSpec else {
                return .default
            }
            return KDFSpec(spec) ?? .default
        }()
        guard let masterKey = createMasterKey(using: masterPassword, words: words, kdfSpec: kdfSpec) else {
            completion(.failure(.masterKey))
            return
        }
        extractPasswordsUsingMasterKey(masterKey, exchangeVault: vault, completion: completion)
    }
    
    func extractPasswordsUsingMasterKey(
        _ masterKey: MasterKey,
        exchangeVault: ExchangeVault,
        completion: @escaping (Result<([PasswordData], [ItemTagData], [DeletedItemData]), ImportExtractMasterPasswordEncryptionError>) -> Void
    ) {
        guard let vaultID = UUID(uuidString: exchangeVault.vault.id) else {
            completion(.failure(.incorrectVaultID))
            return
        }
        guard let reference = exchangeVault.encryption?.reference else {
            completion(.failure(.noReference))
            return
        }
        
        let key: SymmetricKey
        switch validateReference(reference, using: masterKey, for: vaultID) {
        case .success(let symmKey): key = symmKey
        case .failure(let error):
            switch error {
            case .masterKey:
                completion(.failure(.masterKey))
            case .symmetricalKey:
                completion(.failure(.symmetricalKey))
            case .noReference:
                completion(.failure(.noReference))
            case .decryptingReference:
                completion(.failure(.decryptingReference))
            case .referenceMismatch:
                completion(.failure(.referenceMismatch))
            }
            return
        }
        
        guard let passwords = exchangeVault.vault.loginsEncrypted else {
            completion(.failure(.noPasswords))
            return
        }
        let deletedPasswords = exchangeVault.vault.itemsDeletedEncrypted ?? []
        let tags = exchangeVault.vault.tagsEncrypted ?? []
        
        extractPasswords(from: passwords, tags: tags, deletedPasswords: deletedPasswords, vaultID: vaultID, using: key) { passwords, tagsData, deleted in
            completion(.success((passwords, tagsData, deleted)))
        }
    }
    
    func validateReference(
        _ reference: String,
        using masterKey: MasterKey,
        for vaultID: VaultID
    ) -> Result<SymmetricKey, ImportExtractMasterPasswordReferenceVerificationError> {
        guard let key = protectionInteractor.createExternalSymmetricKey(from: masterKey, vaultID: vaultID) else {
            return .failure(.symmetricalKey)
        }
        guard let data = Data(base64Encoded: reference) else {
            return .failure(.noReference)
        }
        guard let decryptedValue = mainRepository.decrypt(data, key: key), let uuidString = String(data: decryptedValue, encoding: .utf8) else {
            return .failure(.decryptingReference)
        }
        guard let original = UUID(uuidString: uuidString), original == vaultID else {
            return .failure(.referenceMismatch)
        }
        return .success(key)
    }
    
    func validateWords(_ words: [String], using seedHash: String, vaultID: VaultID) -> Bool {
        Log("ImportInteractor: Validate Words", module: .interactor)
        
        guard let bitPacks = mainRepository.convertWordsTo4BitPacksAndCRC(words)?.bitPacks else {
            Log("ImportInteractor: Can't create bit packs for validation", module: .interactor)
            return false
        }
              
        let seed = mainRepository.createSeed(from: bitPacks)
        guard let comparisionSeedHash = mainRepository.generateExchangeSeedHash(vaultID, using: seed) else {
            Log("ImportInteractor: Can't create SeedHash for validation", module: .interactor)
            return false
        }
        guard let externalSeedHashHexString = Data(base64Encoded: seedHash)?.hexEncodedString()
        else {
            Log("ImportInteractor: Can't create Seed Hash Hex String for validation", module: .interactor)
            return false
        }
        return comparisionSeedHash == externalSeedHashHexString
    }
    
    func isVaultReadyForImport() -> Bool {
        mainRepository.trustedKey != nil
    }
    
    func scan(image: UIImage, completion: @escaping VisionScanCompletion) {
        mainRepository.scan(image: image, completion: completion)
    }
    
    func generateSeedHash(from entropy: Entropy, vaultID: VaultID) -> String? {
        let seed = mainRepository.createSeed(from: entropy)
        return mainRepository.generateExchangeSeedHash(vaultID, using: seed)
    }
}

private extension ImportInteractor {
    func createMasterKey(
        using masterPassword: MasterPassword,
        words: [String],
        kdfSpec: KDFSpec
    ) -> MasterKey? {
        Log(
            "ImportInteractor: Creating Master Key using Master Password: \(masterPassword) and Words: \(words)",
            module: .interactor
        )
        Log("ImportInteractor: Creating Salt from Words", module: .interactor)
        guard let salt = mainRepository.createSalt(from: words) else {
            Log("ImportInteractor: Error while creating Salt", module: .interactor, severity: .error)
            return nil
        }
        Log("ImportInteractor: Salt: \(salt.hexEncodedString())", module: .interactor)
        guard let (entropy, oldCRC) = mainRepository.convertWordsTo4BitPacksAndCRC(words) else {
            Log("ImportInteractor: Error while creating Entropy and CRC", module: .interactor, severity: .error)
            return nil
        }
        
        Log(
            "ImportInteractor: Entropy: \(entropy.hexEncodedString()), CRC: \(oldCRC, privacy: .private)",
            module: .interactor
        )
        
        let seed = mainRepository.createSeed(from: entropy)
        Log(
            "ImportInteractor: Seed: \(seed.hexEncodedString())",
            module: .interactor
        )
                
        Log("ImportInteractor: Generating Master Key", module: .interactor)
        guard let masterKey = mainRepository.generateMasterKey(with: masterPassword, seed: seed, salt: salt, kdfSpec: kdfSpec) else {
            Log("ImportInteractor: Error while generating Master Key", module: .interactor, severity: .error)
            return nil
        }
        Log("ImportInteractor: Master Key: \(masterKey.hexEncodedString())", module: .interactor)
        return masterKey
    }
    
    func extractPasswords(
        from passwords: [String],
        tags: [String],
        deletedPasswords: [String],
        vaultID: VaultID,
        using key: SymmetricKey,
        completion: @escaping ([PasswordData], [ItemTagData], [DeletedItemData]) -> Void
    ) {
        func parse(_ string: String) -> PasswordData? {
            let jsonDecoder = mainRepository.jsonDecoder
            guard let data = Data(base64Encoded: string) else {
                Log("Import Interactor - Error creating Data from base64 encoded string for Password", severity: .error)
                return nil
            }
            
                guard let jsonData = self.mainRepository.decrypt(data, key: key) else {
                    Log("Import Interactor - Error decrypting JSON data for Password", severity: .error)
                    return nil
                }
                    do {
                        let exchangeLogin = try jsonDecoder.decode(
                            ExchangeVault.ExchangeVaultItem.ExchangeLogin.self,
                            from: jsonData
                        )
                        if let pass = self.exchangeLoginToPasswordData(exchangeLogin) {
                            return pass
                        } else {
                            Log("Import Interactor - Error creating Password Data", severity: .error)
                        }
                    } catch {
                        Log("Import Interactor - Error while parsing ExchangeLogin for Password: \(error)", severity: .error)
                    }
            return nil
        }
        
        Log("ImportInteractor - importing \(passwords.count) passwords and \(deletedPasswords.count) deleted entries", module: .interactor)
        
        if passwords.isEmpty {
            Log("ImportInteractor - no passwords to parse", module: .interactor)
            continueExtractionOfPasswordsTags(
                passwords: [],
                tags: tags,
                deletedPasswords: deletedPasswords,
                vaultID: vaultID,
                using: key,
                completion: completion
            )
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let group = DispatchGroup()
            
            var results: [PasswordData] = []
            
            for string in passwords {
                group.enter()
                self.queue.async {
                    let result = parse(string)
                    self.writeQueue.async {
                        if let result {
                            results.append(result)
                        }
                        group.leave()
                    }
                }
            }
            
            group.notify(queue: .global()) {
                Log("ImportInteractor - parsed \(results.count) passwords", module: .interactor)
                self.continueExtractionOfPasswordsTags(
                    passwords: results,
                    tags: tags,
                    deletedPasswords: deletedPasswords,
                    vaultID: vaultID,
                    using: key,
                    completion: completion
                )
            }
        }
    }

    func continueExtractionOfPasswordsTags(
        passwords: [PasswordData],
        tags: [String],
        deletedPasswords: [String],
        vaultID: VaultID,
        using key: SymmetricKey,
        completion: @escaping ([PasswordData], [ItemTagData], [DeletedItemData]) -> Void
    ) {
        func parse(_ string: String) -> ItemTagData? {
            let jsonDecoder = mainRepository.jsonDecoder
            guard let data = Data(base64Encoded: string) else {
                Log("Import Interactor - Error creating Data from base64 encoded string for Tag", severity: .error)
                return nil
            }
            
                guard let jsonData = self.mainRepository.decrypt(data, key: key) else {
                    Log("Import Interactor - Error decrypting JSON data for Tag", severity: .error)
                    return nil
                }
                    do {
                        let exchangeLogin = try jsonDecoder.decode(
                            ExchangeVault.ExchangeVaultItem.ExchangeTag.self,
                            from: jsonData
                        )
                        if let tag = self.exchangeTagToItemTagData(exchangeLogin, vaultID: vaultID) {
                            return tag
                        } else {
                            Log("Import Interactor - Error creating ItemTagData", severity: .error)
                        }
                    } catch {
                        Log("Import Interactor - Error while parsing ExchangeTag for Tagd: \(error)", severity: .error)
                    }
            return nil
        }

        let decryptedTags = tags.compactMap(parse)
        continueExtractionOfDeletedPasswords(passwords: passwords, tags: decryptedTags, deletedPasswords: deletedPasswords, vaultID: vaultID, using: key, completion: completion)
    }
    
    func continueExtractionOfDeletedPasswords(
        passwords: [PasswordData],
        tags: [ItemTagData],
        deletedPasswords: [String],
        vaultID: VaultID,
        using key: SymmetricKey,
        completion: @escaping ([PasswordData], [ItemTagData], [DeletedItemData]) -> Void
    ) {
        func parse(_ string: String, vaultID: VaultID) -> DeletedItemData? {
            let jsonDecoder = mainRepository.jsonDecoder
            
            guard let data = Data(base64Encoded: string) else {
                Log("Import Interactor - Error creating Data from base64 encoded string for Deleted", severity: .error)
                return nil
            }
            guard let jsonData = self.mainRepository.decrypt(data, key: key) else {
                Log("Import Interactor - Error decrypting JSON data for Deleted", severity: .error)
                return nil
            }
            do {
                let exchangeDeleted = try jsonDecoder.decode(
                    ExchangeVault.ExchangeVaultItem.ExchangeDeletedItem.self,
                    from: jsonData
                )
                if let deleted = self.exchangeDeletedPasswordToDeletedPasswordData(exchangeDeleted, vaultID: vaultID) {
                    return deleted
                } else {
                    Log("Import Interactor - Error creating Deleted Password Data", severity: .error)
                }
            } catch {
                Log("Import Interactor - Error while parsing ExchangeLogin for Deleted: \(error)", severity: .error)
            }
            return nil
        }
        
        Log("ImportInteractor - importing \(deletedPasswords.count) deleted entries", module: .interactor)
        
        if deletedPasswords.isEmpty {
            DispatchQueue.main.async {
                completion(passwords, tags, [])
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let group = DispatchGroup()
            
            var deletedResults: [DeletedItemData] = []
            
            for string in deletedPasswords {
                group.enter()
                self.queue.async {
                    let result = parse(string, vaultID: vaultID)
                    self.writeQueue.async {
                        if let result {
                            deletedResults.append(result)
                        }
                        group.leave()
                    }
                }
            }
            
            group.notify(queue: .main) {
                Log("ImportInteractor - parsed \(passwords.count) passwords and \(deletedResults.count) deleted entries", module: .interactor)
                completion(passwords, tags, deletedResults)
            }
        }
    }
    
    func exchangeLoginToPasswordData(_ exchangeLogin: ExchangeVault.ExchangeVaultItem.ExchangeLogin) -> PasswordData? {
        guard let passwordID = UUID(uuidString: exchangeLogin.id)
        else {
            return nil
        }
        let protectionLevel: ItemProtectionLevel = {
            switch exchangeLogin.securityType {
            case 0: .topSecret
            case 1: .confirm
            case 2: .normal
            default: .normal
            }
        }()
        
        guard let key = mainRepository.getKey(isPassword: true, protectionLevel: protectionLevel) else {
            return nil
        }
        
        let password: Data? = {
            guard let passwordEntry = exchangeLogin.password, let passwordData = passwordEntry.data(using: .utf8) else {
                return nil
            }
            guard let password = mainRepository.encrypt(passwordData, key: key) else {
                return nil
            }
            return password
        }()
        
        let iconType: PasswordIconType = {
            switch exchangeLogin.iconType {
            case 0:
                guard let uriIndex = exchangeLogin.iconUriIndex, let uri = exchangeLogin.uris?[uriIndex], let domain = uriInteractor.extractDomain(from: uri.text) else {
                    return .domainIcon(nil)
                }
                return .domainIcon(domain)
                
            case 2:
                guard let urlString = exchangeLogin.customImageUrl, let url = URL(string: urlString) else {
                    return .domainIcon(nil)
                }
                return .customIcon(url)
                
            default:
                let title = exchangeLogin.labelText ?? exchangeLogin.name.map { Config.defaultIconLabel(forName: $0) } ?? Config.defaultIconLabel
                let color = UIColor(hexString: exchangeLogin.labelColor)
                return .label(labelTitle: title, labelColor: color)
            }
        }()
        
        let uris: [PasswordURI]? = { () -> [PasswordURI]? in
            guard let uris = exchangeLogin.uris, !uris.isEmpty else {
                return nil
            }
            return uris.map { exchangeURI in
                let uri = exchangeURI.text
            
                return PasswordURI(
                    uri: uri,
                    match: {
                    switch exchangeURI.matcher {
                    case 0: .domain
                    case 1: .host
                    case 2: .startsWith
                    case 3: .exact
                    default: .domain
                    }
                }())
            }
        }()
        
        return PasswordData(
            passwordID: passwordID,
            name: exchangeLogin.name.formattedName,
            username: exchangeLogin.username,
            password: password,
            notes: exchangeLogin.notes?.sanitizeNotes(),
            creationDate: Date(exportTimestamp: exchangeLogin.createdAt),
            modificationDate: Date(exportTimestamp: exchangeLogin.updatedAt),
            iconType: iconType,
            trashedStatus: .no,
            protectionLevel: protectionLevel,
            uris: uris,
            tagIds: exchangeLogin.tags?.compactMap { UUID(uuidString: $0) }
        )
    }
    
    func exchangeTagToItemTagData(_ exchangeTag: ExchangeVault.ExchangeVaultItem.ExchangeTag, vaultID: VaultID) -> ItemTagData? {
        guard let tagID = ItemTagID(uuidString: exchangeTag.id) else { return nil }
        return ItemTagData(
            tagID: tagID,
            vaultID: vaultID,
            name: exchangeTag.name,
            color: UIColor(hexString: exchangeTag.color),
            position: exchangeTag.position,
            modificationDate: Date(exportTimestamp: exchangeTag.updatedAt)
        )
    }
    
    func exchangeDeletedPasswordToDeletedPasswordData(
        _ exchangeDeleted: ExchangeVault.ExchangeVaultItem.ExchangeDeletedItem,
        vaultID: VaultID
    ) -> DeletedItemData? {
        guard let itemID = ItemTagID(uuidString: exchangeDeleted.id) else { return nil }
        guard let kind = DeletedItemData.Kind(rawValue: exchangeDeleted.type) else { return nil }
        return .init(itemID: itemID, vaultID: vaultID, kind: kind, deletedAt: Date(exportTimestamp: exchangeDeleted.deletedAt))
    }
}
