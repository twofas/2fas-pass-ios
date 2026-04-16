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

extension ImportExtractMasterPasswordEncryptionError {
    init(_ referenceError: ImportExtractMasterPasswordReferenceVerificationError) {
        switch referenceError {
        case .masterKey: self = .masterKey
        case .symmetricalKey: self = .symmetricalKey
        case .noReference: self = .noReference
        case .decryptingReference: self = .decryptingReference
        case .referenceMismatch: self = .referenceMismatch
        }
    }
}

public typealias ImportedDataPayload = ([ItemData], [ItemTagData], [DeletedItemData])
public typealias ImportedDecryptedDataPayload = ([ItemDecryptedData], [ItemTagData], [DeletedItemData])

public protocol ImportInteracting: AnyObject {
    func openFile(url: URL) async throws(ImportOpenFileError) -> Data
    func parseContents(of data: Data) async throws(ImportParseError) -> ExchangeVaultVersioned
    func checkDeviceId(in vault: ExchangeVaultVersioned) -> Bool
    func checkEncryption(in vault: ExchangeVaultVersioned) -> ImportEncryptionType
    func checkEncryptionWithoutParsing(in vault: ExchangeVaultVersioned) -> ImportEncryptionTypeNoParsing

    func extractDataUsingCurrentEncryption(
        from vault: ExchangeVaultVersioned
    ) async throws(ImportExtractCurrentEncryptionError) -> ImportedDataPayload

    func extractDecryptedDataUsingCurrentEncryption(
        from vault: ExchangeVaultVersioned
    ) async throws(ImportExtractCurrentEncryptionError) -> ImportedDecryptedDataPayload

    func extractUnencryptedItems(from file: ExchangeVaultVersioned) -> [ItemData]
    func extractUnencryptedTags(from file: ExchangeVaultVersioned) -> [ItemTagData]
    func extractDecryptedUnencryptedItems(from file: ExchangeVaultVersioned) -> [ItemDecryptedData]

    func extractDataUsingMasterPassword(
        _ masterPassword: MasterPassword,
        words: [String],
        vault: ExchangeVaultVersioned
    ) async throws(ImportExtractMasterPasswordEncryptionError) -> ImportedDataPayload

    func extractItemsUsingMasterKey(
        _ masterKey: MasterKey,
        exchangeVault: ExchangeVaultVersioned
    ) async throws(ImportExtractMasterPasswordEncryptionError) -> ImportedDataPayload

    func extractDecryptedItemsUsingMasterKey(
        _ masterKey: MasterKey,
        exchangeVault: ExchangeVaultVersioned
    ) async throws(ImportExtractMasterPasswordEncryptionError) -> ImportedDecryptedDataPayload
    
    func extractUnencryptedDeletedItems(from file: ExchangeVaultVersioned) -> [DeletedItemData]
    func validateWords(_ words: [String], using seedHash: String, vaultID: VaultID) -> Bool
    
    func validateReference(
        _ reference: String,
        using masterKey: MasterKey,
        for vaultID: VaultID
    ) -> Result<SymmetricKey, ImportExtractMasterPasswordReferenceVerificationError>
    
    func isVaultReadyForImport() -> Bool
    func generateSeedHash(from entropy: Entropy, vaultID: VaultID) -> String?
    func encryptItem(_ decrypted: ItemDecryptedData, forVault targetVaultID: VaultID) -> ItemData?
    func rebindTag(_ tag: ItemTagData, forVault targetVaultID: VaultID) -> ItemTagData
}

final class ImportInteractor {
    private let mainRepository: MainRepository
    private let vaultsInteractor: VaultsInteracting
    private let itemsInteractor: ItemsInteracting
    private let protectionInteractor: ProtectionInteracting
    private let uriInteractor: URIInteracting

    private var vaultID: VaultID {
        vaultsInteractor.defaultVaultID
    }

    init(
        mainRepository: MainRepository,
        vaultsInteractor: VaultsInteracting,
        itemsInteractor: ItemsInteracting,
        protectionInteractor: ProtectionInteracting,
        uriInteractor: URIInteracting
    ) {
        self.mainRepository = mainRepository
        self.vaultsInteractor = vaultsInteractor
        self.itemsInteractor = itemsInteractor
        self.protectionInteractor = protectionInteractor
        self.uriInteractor = uriInteractor
    }
}

extension ImportInteractor: ImportInteracting {
    func openFile(url: URL) async throws(ImportOpenFileError) -> Data {
        do {
            var data: Data?
            var readError: Error?
            if url.startAccessingSecurityScopedResource() {
                var coordinatorError: NSError?
                NSFileCoordinator().coordinate(readingItemAt: url, options: [.withoutChanges], error: &coordinatorError) { url in
                    do {
                        data = try Data(contentsOf: url)
                    } catch {
                        readError = error
                    }
                }
                url.stopAccessingSecurityScopedResource()
                if let coordinatorError {
                    throw ImportOpenFileError.cantReadFile(reason: coordinatorError.localizedDescription)
                }
            } else {
                data = try Data(contentsOf: url)
            }

            guard let data else {
                throw ImportOpenFileError.cantReadFile(reason: readError?.localizedDescription)
            }

            return data
        } catch let error as ImportOpenFileError {
            throw error
        } catch {
            Log("Can't import data from file: \(url), error: \(error)")
            throw .cantReadFile(reason: error.localizedDescription)
        }
    }
    
    func parseContents(of data: Data) async throws(ImportParseError) -> ExchangeVaultVersioned {
        let jsonDecoder = mainRepository.jsonDecoder
        do {
            let parsedJSON = try jsonDecoder.decode(ExchangeVault.self, from: data)
            return .v2(parsedJSON)
        } catch let ExchangeError.mismatchSchemaVersion(schemaVersion, expected: _) {
            guard schemaVersion <= Config.schemaVersion else {
                throw .schemaNotSupported(schemaVersion)
            }
            do {
                switch schemaVersion {
                case 1:
                    let parsedJSON = try jsonDecoder.decode(ExchangeSchemaV1.ExchangeVault.self, from: data)
                    return .v1(parsedJSON)
                default:
                    throw ImportParseError.schemaNotSupported(schemaVersion)
                }
            } catch let error as ImportParseError {
                throw error
            } catch {
                throw .jsonError(error)
            }
        } catch {
            throw .jsonError(error)
        }
    }
    
    func checkDeviceId(in vault: ExchangeVaultVersioned) -> Bool {
        mainRepository.deviceID == vault.deviceId
    }

    func checkEncryption(in file: ExchangeVaultVersioned) -> ImportEncryptionType {
        if file.hasUnencryptedServices {
            return .noEncryption
        }
        guard let key = mainRepository.cachedExternalKey(forVault: vaultID) else {
            return .noExternalKeyError
        }
        guard !vaultsInteractor.listVaults().isEmpty else {
            return .noSelectedVaultError
        }
        guard let encryption = file.encryption, let data = Data(base64Encoded: encryption.reference) else {
            return .missingEncryptionError
        }
        guard let reference = mainRepository.decrypt(data, key: key),
              let string = String(data: reference, encoding: .utf8),
              UUID(uuidString: string) == vaultID
        else {
            if encryption.seedHash == mainRepository.createSeedHashHexForExport(forVault: vaultID) {
                return .passwordChanged
            } else {
                return .needsPasswordWords
            }
        }
        return .currentEncryption
    }
    
    func extractUnencryptedItems(from file: ExchangeVaultVersioned) -> [ItemData] {
        guard let vaultID = UUID(uuidString: file.vaultID) else {
            return []
        }
        switch file {
        case .v1(let v1Vault):
            guard let logins = v1Vault.vault.logins else {
                return []
            }
            return logins.compactMap({ self.exchangeV1LoginToItemData($0, vaultID: vaultID) })
        case .v2(let v2Vault):
            guard let items = v2Vault.vault.items else {
                return []
            }
            return items.compactMap({ self.exchangeItemToItemData($0, vaultID: vaultID, encryption: .unencrypted) })
        }
    }

    func extractUnencryptedDeletedItems(from file: ExchangeVaultVersioned) -> [DeletedItemData] {
        guard let vaultID = UUID(uuidString: file.vaultID) else {
            return []
        }
        return file.itemsDeleted.compactMap({ self.exchangeDeletedPasswordToDeletedPasswordData($0, vaultID: vaultID) })
    }

    func extractUnencryptedTags(from file: ExchangeVaultVersioned) -> [ItemTagData] {
        return file.tags.compactMap({ self.exchangeTagToItemTagData($0, vaultID: vaultID) })
    }

    func extractDecryptedUnencryptedItems(from file: ExchangeVaultVersioned) -> [ItemDecryptedData] {
        guard let vaultID = UUID(uuidString: file.vaultID) else { return [] }
        switch file {
        case .v1(let v1Vault):
            guard let logins = v1Vault.vault.logins else { return [] }
            return logins.compactMap { self.exchangeV1LoginToDecryptedItemData($0, vaultID: vaultID) }
        case .v2(let v2Vault):
            guard let items = v2Vault.vault.items else { return [] }
            // Unencrypted exchange format stores secure fields as plaintext — identity transform.
            return items.compactMap { item in
                self.exchangeItemToDecryptedItemData(item, vaultID: vaultID, secureFieldPlaintext: { plaintext, _ in plaintext })
            }
        }
    }

    func checkEncryptionWithoutParsing(in vault: ExchangeVaultVersioned) -> ImportEncryptionTypeNoParsing {
        if vault.hasUnencryptedServices {
            return .noEncryption
        }
        return .needsPassword
    }
    
    func extractDataUsingCurrentEncryption(
        from vault: ExchangeVaultVersioned
    ) async throws(ImportExtractCurrentEncryptionError) -> ImportedDataPayload {
        guard let key = mainRepository.cachedExternalKey(forVault: vaultID) else {
            throw .noExternalKey
        }

        guard let vaultID = UUID(uuidString: vault.vaultID) else {
            throw .noVaultID
        }

        switch vault {
        case .v1(let v1Vault):
            guard let loginsEncrypted = v1Vault.vault.loginsEncrypted else {
                throw .noPasswordsField
            }
            let deletedPasswords = v1Vault.vault.itemsDeletedEncrypted ?? []
            let tags = v1Vault.vault.tagsEncrypted ?? []
            return await extractDataV1(from: loginsEncrypted, tags: tags, deleted: deletedPasswords, vaultID: vaultID, using: key)

        case .v2(let v2Vault):
            guard let itemsEncrypted = v2Vault.vault.itemsEncrypted else {
                throw .noPasswordsField
            }
            let deletedPasswords = v2Vault.vault.itemsDeletedEncrypted ?? []
            let tags = v2Vault.vault.tagsEncrypted ?? []
            return await extractDataV2(from: itemsEncrypted, tags: tags, deleted: deletedPasswords, vaultID: vaultID, using: key)
        }
    }

    public func extractDecryptedDataUsingCurrentEncryption(
        from vault: ExchangeVaultVersioned
    ) async throws(ImportExtractCurrentEncryptionError) -> ImportedDecryptedDataPayload {
        guard let vaultID = UUID(uuidString: vault.vaultID) else {
            throw .noVaultID
        }
        guard let outerKey = mainRepository.cachedExternalKey(forVault: vaultID) else {
            throw .noExternalKey
        }

        let encryptedItems: [String]
        let encryptedTags: [String]
        let encryptedDeleted: [String]
        let isV1: Bool
        switch vault {
        case .v1(let v1Vault):
            guard let items = v1Vault.vault.loginsEncrypted else {
                throw .noPasswordsField
            }
            encryptedItems = items
            encryptedTags = v1Vault.vault.tagsEncrypted ?? []
            encryptedDeleted = v1Vault.vault.itemsDeletedEncrypted ?? []
            isV1 = true
        case .v2(let v2Vault):
            guard let items = v2Vault.vault.itemsEncrypted else {
                throw .noPasswordsField
            }
            encryptedItems = items
            encryptedTags = v2Vault.vault.tagsEncrypted ?? []
            encryptedDeleted = v2Vault.vault.itemsDeletedEncrypted ?? []
            isV1 = false
        }

        let keyProvider: @Sendable (ItemProtectionLevel) -> SymmetricKey? = { [mainRepository] level in
            mainRepository.getKey(isPassword: true, protectionLevel: level, forVault: vaultID)
        }

        async let parsedItems: [ItemDecryptedData] = decryptAndParse(encryptedItems, using: outerKey) { [self] jsonData, decoder in
            if isV1 {
                let login = try decoder.decode(ExchangeSchemaV1.ExchangeVault.ExchangeVaultItem.ExchangeLogin.self, from: jsonData)
                return self.exchangeV1LoginToDecryptedItemData(login, vaultID: vaultID)
            } else {
                let item = try decoder.decode(ExchangeVault.ExchangeVaultItem.ExchangeItem.self, from: jsonData)
                return self.exchangeItemToDecryptedItemData(item, vaultID: vaultID, secureFieldPlaintext: { [mainRepository] base64, level in
                    guard let key = keyProvider(level),
                          let cipher = Data(base64Encoded: base64),
                          let plain = mainRepository.decrypt(cipher, key: key),
                          let string = String(data: plain, encoding: .utf8) else { return nil }
                    return string
                })
            }
        }

        async let parsedTags: [ItemTagData] = decryptAndParse(encryptedTags, using: outerKey) { [self] jsonData, decoder in
            let exchangeTag = try decoder.decode(ExchangeVault.ExchangeVaultItem.ExchangeTag.self, from: jsonData)
            return self.exchangeTagToItemTagData(exchangeTag, vaultID: vaultID)
        }

        async let parsedDeleted: [DeletedItemData] = decryptAndParse(encryptedDeleted, using: outerKey) { [self] jsonData, decoder in
            let exchangeDeleted = try decoder.decode(ExchangeVault.ExchangeVaultItem.ExchangeDeletedItem.self, from: jsonData)
            return self.exchangeDeletedPasswordToDeletedPasswordData(exchangeDeleted, vaultID: vaultID)
        }

        return await (parsedItems, parsedTags, parsedDeleted)
    }

    func extractDataUsingMasterPassword(
        _ masterPassword: MasterPassword,
        words: [String],
        vault: ExchangeVaultVersioned
    ) async throws(ImportExtractMasterPasswordEncryptionError) -> ImportedDataPayload {
        let kdfSpec: KDFSpec = {
            guard let spec = vault.encryption?.kdfSpec else {
                return .default
            }
            return KDFSpec(spec) ?? .default
        }()
        guard let masterKey = createMasterKey(using: masterPassword, words: words, kdfSpec: kdfSpec) else {
            throw .masterKey
        }
        return try await extractItemsUsingMasterKey(masterKey, exchangeVault: vault)
    }

    func extractItemsUsingMasterKey(
        _ masterKey: MasterKey,
        exchangeVault: ExchangeVaultVersioned
    ) async throws(ImportExtractMasterPasswordEncryptionError) -> ImportedDataPayload {
        guard let vaultID = UUID(uuidString: exchangeVault.vaultID) else {
            throw .incorrectVaultID
        }
        guard let reference = exchangeVault.encryption?.reference else {
            throw .noReference
        }

        let key: SymmetricKey = try validateReference(reference, using: masterKey, for: vaultID)
            .mapError { ImportExtractMasterPasswordEncryptionError($0) }
            .get()

        switch exchangeVault {
        case .v1(let v1Vault):
            guard let loginsEncrypted = v1Vault.vault.loginsEncrypted else {
                throw .noPasswords
            }
            let deletedPasswords = v1Vault.vault.itemsDeletedEncrypted ?? []
            let tags = v1Vault.vault.tagsEncrypted ?? []
            return await extractDataV1(from: loginsEncrypted, tags: tags, deleted: deletedPasswords, vaultID: vaultID, using: key)

        case .v2(let v2Vault):
            guard let itemsEncrypted = v2Vault.vault.itemsEncrypted else {
                throw .noPasswords
            }
            let deletedPasswords = v2Vault.vault.itemsDeletedEncrypted ?? []
            let tags = v2Vault.vault.tagsEncrypted ?? []
            return await extractDataV2(from: itemsEncrypted, tags: tags, deleted: deletedPasswords, vaultID: vaultID, using: key, importMasterKey: masterKey)
        }
    }

    public func extractDecryptedItemsUsingMasterKey(
        _ masterKey: MasterKey,
        exchangeVault: ExchangeVaultVersioned
    ) async throws(ImportExtractMasterPasswordEncryptionError) -> ImportedDecryptedDataPayload {
        guard let vaultID = UUID(uuidString: exchangeVault.vaultID) else {
            throw .incorrectVaultID
        }
        guard let reference = exchangeVault.encryption?.reference else {
            throw .noReference
        }
        let outerKey: SymmetricKey = try validateReference(reference, using: masterKey, for: vaultID)
            .mapError { ImportExtractMasterPasswordEncryptionError($0) }
            .get()

        guard let importTrustedKey = getImportKey(for: .normal, masterKey: masterKey, vaultID: vaultID),
              let importSecureKey = getImportKey(for: .topSecret, masterKey: masterKey, vaultID: vaultID) else {
            Log("Import Interactor - Error deriving import keys", severity: .error)
            return ([], [], [])
        }

        let encryptedItems: [String]
        let encryptedTags: [String]
        let encryptedDeleted: [String]
        let isV1: Bool
        switch exchangeVault {
        case .v1(let v1Vault):
            guard let items = v1Vault.vault.loginsEncrypted else {
                throw .noPasswords
            }
            encryptedItems = items
            encryptedTags = v1Vault.vault.tagsEncrypted ?? []
            encryptedDeleted = v1Vault.vault.itemsDeletedEncrypted ?? []
            isV1 = true
        case .v2(let v2Vault):
            guard let items = v2Vault.vault.itemsEncrypted else {
                throw .noPasswords
            }
            encryptedItems = items
            encryptedTags = v2Vault.vault.tagsEncrypted ?? []
            encryptedDeleted = v2Vault.vault.itemsDeletedEncrypted ?? []
            isV1 = false
        }

        async let parsedItems: [ItemDecryptedData] = decryptAndParse(encryptedItems, using: outerKey) { [self] jsonData, decoder in
            if isV1 {
                let login = try decoder.decode(ExchangeSchemaV1.ExchangeVault.ExchangeVaultItem.ExchangeLogin.self, from: jsonData)
                return self.exchangeV1LoginToDecryptedItemData(login, vaultID: vaultID)
            } else {
                let item = try decoder.decode(ExchangeVault.ExchangeVaultItem.ExchangeItem.self, from: jsonData)
                return self.exchangeItemToDecryptedItemData(item, vaultID: vaultID, secureFieldPlaintext: { [mainRepository] base64, level in
                    let key: SymmetricKey = {
                        switch level {
                        case .normal: importTrustedKey
                        case .confirm, .topSecret: importSecureKey
                        }
                    }()
                    guard let cipher = Data(base64Encoded: base64),
                          let plain = mainRepository.decrypt(cipher, key: key),
                          let string = String(data: plain, encoding: .utf8) else { return nil }
                    return string
                })
            }
        }

        async let parsedTags: [ItemTagData] = decryptAndParse(encryptedTags, using: outerKey) { [self] jsonData, decoder in
            let exchangeTag = try decoder.decode(ExchangeVault.ExchangeVaultItem.ExchangeTag.self, from: jsonData)
            return self.exchangeTagToItemTagData(exchangeTag, vaultID: vaultID)
        }

        async let parsedDeleted: [DeletedItemData] = decryptAndParse(encryptedDeleted, using: outerKey) { [self] jsonData, decoder in
            let exchangeDeleted = try decoder.decode(ExchangeVault.ExchangeVaultItem.ExchangeDeletedItem.self, from: jsonData)
            return self.exchangeDeletedPasswordToDeletedPasswordData(exchangeDeleted, vaultID: vaultID)
        }

        return await (parsedItems, parsedTags, parsedDeleted)
    }

    public func encryptItem(_ decrypted: ItemDecryptedData, forVault targetVaultID: VaultID) -> ItemData? {
        guard let targetKey = mainRepository.getKey(isPassword: true, protectionLevel: decrypted.metadata.protectionLevel, forVault: targetVaultID) else {
            Log("ImportInteractor - encryptItem: missing key for target vault \(targetVaultID)", severity: .error)
            return nil
        }
        guard let plaintextBytes = try? decrypted.encodeContent(using: mainRepository.jsonEncoder),
              let encryptedData = transformSecureFields(in: plaintextBytes, contentType: decrypted.contentType, transform: { plainString in
                  guard let plainData = plainString.data(using: .utf8),
                        let cipher = mainRepository.encrypt(plainData, key: targetKey) else { return nil }
                  return cipher.base64EncodedString()
              }) else {
            return nil
        }
        let rawItem = RawItemData(
            id: decrypted.id,
            vaultId: targetVaultID,
            metadata: decrypted.metadata,
            name: decrypted.name,
            contentType: decrypted.contentType,
            contentVersion: decrypted.contentVersion,
            content: encryptedData
        )
        return ItemData(rawItem, decoder: mainRepository.jsonDecoder)
    }

    public func rebindTag(_ tag: ItemTagData, forVault targetVaultID: VaultID) -> ItemTagData {
        tag.update(vaultId: targetVaultID)
    }

    /// `secureFieldPlaintext` takes a raw secure-field value from the exchange payload and
    /// returns the plaintext string. For encrypted inputs, callers implement decrypt logic
    /// (base64 → decrypt → UTF-8); for unencrypted inputs, callers return the input as-is.
    private func exchangeItemToDecryptedItemData(
        _ exchangeItem: ExchangeVault.ExchangeVaultItem.ExchangeItem,
        vaultID: VaultID,
        secureFieldPlaintext: (String, ItemProtectionLevel) -> String?
    ) -> ItemDecryptedData? {
        guard let itemID = UUID(uuidString: exchangeItem.id) else { return nil }

        let protectionLevel = protectionLevel(fromSecurityType: exchangeItem.securityType)

        let itemMetadata = ItemMetadata(
            creationDate: Date(exportTimestamp: exchangeItem.createdAt),
            modificationDate: Date(exportTimestamp: exchangeItem.updatedAt),
            protectionLevel: protectionLevel,
            trashedStatus: .no,
            tagIds: exchangeItem.tags?.compactMap { UUID(uuidString: $0) }
        )

        let contentType = ItemContentType(rawValue: exchangeItem.contentType)

        switch contentType {
        case .login:
            guard let rawContentData = try? mainRepository.jsonEncoder.encode(AnyCodable(exchangeItem.content)),
                  let content = try? mainRepository.jsonDecoder.decode(ExchangeVault.ExchangeVaultItem.ExchangeItem.ExchangeLoginContent.self, from: rawContentData) else {
                return nil
            }

            let plaintextPassword = content.password.flatMap { secureFieldPlaintext($0, protectionLevel) }

            let resolvedDomain: String? = {
                guard content.iconType == 0,
                      let uriIndex = content.iconUriIndex,
                      let uri = content.uris?[safe: uriIndex] else { return nil }
                return uriInteractor.extractDomain(from: uri.text)
            }()

            let iconType = passwordIconType(
                rawIconType: content.iconType,
                resolvedDomain: resolvedDomain,
                customImageUrl: content.customImageUrl,
                labelText: content.labelText,
                labelColor: content.labelColor,
                name: content.name
            )

            let uris = passwordURIs(from: content.uris, text: \.text, matcher: \.matcher)

            return makeLoginDecrypted(
                itemID: itemID,
                vaultID: vaultID,
                metadata: itemMetadata,
                name: content.name,
                username: content.username,
                plaintextPassword: plaintextPassword,
                notes: content.notes?.sanitizeNotes(),
                iconType: iconType,
                uris: uris
            )

        default:
            guard let rawContentData = try? JSONSerialization.data(withJSONObject: exchangeItem.content),
                  let contentData = transformSecureFields(in: rawContentData, contentType: contentType, transform: { fieldValue in
                      secureFieldPlaintext(fieldValue, protectionLevel)
                  }) else {
                return nil
            }
            let itemName = exchangeItem.content[ExchangeVault.contentNameKey] as? String
            let decoder = mainRepository.jsonDecoder

            switch contentType {
            case .secureNote:
                guard let content = try? decoder.decode(SecureNoteItemDecryptedData.Content.self, from: contentData) else {
                    return nil
                }
                return .secureNote(SecureNoteItemDecryptedData(
                    id: itemID,
                    vaultId: vaultID,
                    metadata: itemMetadata,
                    name: itemName,
                    content: content
                ))
            case .paymentCard:
                guard let content = try? decoder.decode(PaymentCardItemDecryptedData.Content.self, from: contentData) else {
                    return nil
                }
                return .paymentCard(PaymentCardItemDecryptedData(
                    id: itemID,
                    vaultId: vaultID,
                    metadata: itemMetadata,
                    name: itemName,
                    content: content
                ))
            case .wifi:
                guard let content = try? decoder.decode(WiFiItemDecryptedData.Content.self, from: contentData) else {
                    return nil
                }
                return .wifi(WiFiItemDecryptedData(
                    id: itemID,
                    vaultId: vaultID,
                    metadata: itemMetadata,
                    name: itemName,
                    content: content
                ))
            case .login, .unknown:
                return .raw(RawItemDecryptedData(
                    id: itemID,
                    vaultId: vaultID,
                    metadata: itemMetadata,
                    name: itemName,
                    contentType: contentType,
                    contentVersion: exchangeItem.contentVersion,
                    content: contentData
                ))
            }
        }
    }

    private func exchangeV1LoginToDecryptedItemData(
        _ exchangeLogin: ExchangeSchemaV1.ExchangeVault.ExchangeVaultItem.ExchangeLogin,
        vaultID: VaultID
    ) -> ItemDecryptedData? {
        guard let itemID = UUID(uuidString: exchangeLogin.id) else { return nil }

        let protectionLevel = protectionLevel(fromSecurityType: exchangeLogin.securityType)

        let itemMetadata = ItemMetadata(
            creationDate: Date(exportTimestamp: exchangeLogin.createdAt),
            modificationDate: Date(exportTimestamp: exchangeLogin.updatedAt),
            protectionLevel: protectionLevel,
            trashedStatus: .no,
            tagIds: exchangeLogin.tags?.compactMap { UUID(uuidString: $0) }
        )

        let resolvedDomain: String? = {
            guard exchangeLogin.iconType == 0,
                  let uriIndex = exchangeLogin.iconUriIndex,
                  let uri = exchangeLogin.uris?[safe: uriIndex] else { return nil }
            return uriInteractor.extractDomain(from: uri.text)
        }()

        let iconType = passwordIconType(
            rawIconType: exchangeLogin.iconType,
            resolvedDomain: resolvedDomain,
            customImageUrl: exchangeLogin.customImageUrl,
            labelText: exchangeLogin.labelText,
            labelColor: exchangeLogin.labelColor,
            name: exchangeLogin.name
        )

        let uris = passwordURIs(from: exchangeLogin.uris, text: \.text, matcher: \.matcher)

        return makeLoginDecrypted(
            itemID: itemID,
            vaultID: vaultID,
            metadata: itemMetadata,
            name: exchangeLogin.name,
            username: exchangeLogin.username,
            plaintextPassword: exchangeLogin.password,
            notes: exchangeLogin.notes?.sanitizeNotes(),
            iconType: iconType,
            uris: uris
        )
    }

    private func makeLoginDecrypted(
        itemID: UUID,
        vaultID: VaultID,
        metadata: ItemMetadata,
        name: String?,
        username: String?,
        plaintextPassword: String?,
        notes: String?,
        iconType: PasswordIconType,
        uris: [PasswordURI]?
    ) -> ItemDecryptedData {
        let loginContent = LoginItemDecryptedContent(
            name: name,
            username: username,
            password: plaintextPassword,
            notes: notes,
            iconType: iconType,
            uris: uris
        )
        return .login(LoginItemDecryptedData(
            id: itemID,
            vaultId: vaultID,
            metadata: metadata,
            name: name,
            content: loginContent
        ))
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
        mainRepository.trustedKey(forVault: vaultID) != nil
    }
    
    func generateSeedHash(from entropy: Entropy, vaultID: VaultID) -> String? {
        let seed = mainRepository.createSeed(from: entropy)
        return mainRepository.generateExchangeSeedHash(vaultID, using: seed)
    }
}

private extension ImportInteractor {
    enum ItemEncryption {
        case unencrypted
        case currentEncryption
        case otherEncryption(trustedKey: SymmetricKey, secureKey: SymmetricKey)
    }

    func getImportKey(for protectionLevel: ItemProtectionLevel, masterKey: MasterKey, vaultID: VaultID) -> SymmetricKey? {
        let key = {
            switch protectionLevel {
            case .normal:
                mainRepository.generateTrustedKeyForVaultID(vaultID, using: masterKey.hexEncodedString())
            case .confirm, .topSecret:
                mainRepository.generateSecureKeyForVaultID(vaultID, using: masterKey.hexEncodedString())
            }
        }()

        guard let key, let keyData = Data(hexString: key) else {
            return nil
        }
        
        return mainRepository.createSymmetricKey(from: keyData)
    }

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
    
    func extractDataV2(
        from items: [String],
        tags: [String],
        deleted: [String],
        vaultID: VaultID,
        using key: SymmetricKey,
        importMasterKey: MasterKey? = nil
    ) async -> ImportedDataPayload {
        let encryption: ItemEncryption
        if let importMasterKey {
            guard let importTrustedKey = getImportKey(for: .normal, masterKey: importMasterKey, vaultID: vaultID),
                  let importSecureKey = getImportKey(for: .topSecret, masterKey: importMasterKey, vaultID: vaultID) else {
                Log("Import Interactor - Error deriving import keys", severity: .error)
                return ([], [], [])
            }
            encryption = .otherEncryption(trustedKey: importTrustedKey, secureKey: importSecureKey)
        } else {
            encryption = .currentEncryption
        }

        Log("ImportInteractor - importing \(items.count) items, \(tags.count) tags and \(deleted.count) deleted entries", module: .interactor)

        async let parsedItems: [ItemData] = decryptAndParse(items, using: key) { [self] jsonData, decoder in
            let exchangeItem = try decoder.decode(
                ExchangeVault.ExchangeVaultItem.ExchangeItem.self,
                from: jsonData
            )
            return self.exchangeItemToItemData(exchangeItem, vaultID: vaultID, encryption: encryption)
        }

        async let parsedTags: [ItemTagData] = decryptAndParse(tags, using: key) { [self] jsonData, decoder in
            let exchangeTag = try decoder.decode(
                ExchangeVault.ExchangeVaultItem.ExchangeTag.self,
                from: jsonData
            )
            return self.exchangeTagToItemTagData(exchangeTag, vaultID: vaultID)
        }

        async let parsedDeleted: [DeletedItemData] = decryptAndParse(deleted, using: key) { [self] jsonData, decoder in
            let exchangeDeleted = try decoder.decode(
                ExchangeVault.ExchangeVaultItem.ExchangeDeletedItem.self,
                from: jsonData
            )
            return self.exchangeDeletedPasswordToDeletedPasswordData(exchangeDeleted, vaultID: vaultID)
        }

        let (resultItems, resultTags, resultDeleted) = await (parsedItems, parsedTags, parsedDeleted)
        Log("ImportInteractor - parsed \(resultItems.count) items, \(resultTags.count) tags and \(resultDeleted.count) deleted entries", module: .interactor)
        return (resultItems, resultTags, resultDeleted)
    }
    
    private func decryptAndParse<T: Sendable>(
        _ encrypted: [String],
        using key: SymmetricKey,
        transform: @escaping @Sendable (Data, JSONDecoder) throws -> T?
    ) async -> [T] {
        guard !encrypted.isEmpty else { return [] }
        return await withTaskGroup(of: T?.self) { group in
            for string in encrypted {
                group.addTask { [mainRepository] in
                    guard let data = Data(base64Encoded: string),
                          let jsonData = mainRepository.decrypt(data, key: key) else {
                        return nil
                    }
                    return try? transform(jsonData, JSONDecoder())
                }
            }
            var collected: [T] = []
            for await result in group {
                if let result { collected.append(result) }
            }
            return collected
        }
    }

    func exchangeItemToItemData(_ exchangeLogin: ExchangeVault.ExchangeVaultItem.ExchangeItem, vaultID: VaultID, encryption: ItemEncryption) -> ItemData? {
        guard let itemID = UUID(uuidString: exchangeLogin.id) else {
            return nil
        }

        let protectionLevel = protectionLevel(fromSecurityType: exchangeLogin.securityType)
        
        let itemMetadata = ItemMetadata(
            creationDate: Date(exportTimestamp: exchangeLogin.createdAt),
            modificationDate: Date(exportTimestamp: exchangeLogin.updatedAt),
            protectionLevel: protectionLevel,
            trashedStatus: .no,
            tagIds: exchangeLogin.tags?.compactMap { UUID(uuidString: $0) }
        )
        
        let contentType = ItemContentType(rawValue: exchangeLogin.contentType)
        
        guard let key = mainRepository.getKey(isPassword: true, protectionLevel: protectionLevel, forVault: vaultID) else {
            return nil
        }
        
        switch contentType {
        case .login:
            guard let contentData = try? mainRepository.jsonEncoder.encode(AnyCodable(exchangeLogin.content)) else {
                return nil
            }

            guard let content = try? mainRepository.jsonDecoder.decode(ExchangeVault.ExchangeVaultItem.ExchangeItem.ExchangeLoginContent.self, from: contentData) else {
                return nil
            }
            
            let password: Data? = {
                guard let passwordEntry = content.password else {
                    return nil
                }
                switch encryption {
                case .unencrypted:
                    // Encrypt plaintext password with current vault key
                    guard let passwordData = passwordEntry.data(using: .utf8),
                          let encryptedPassword = mainRepository.encrypt(passwordData, key: key) else {
                        return nil
                    }
                    return encryptedPassword

                case .currentEncryption:
                    // Password is already encrypted with current vault key
                    guard let passwordData = Data(base64Encoded: passwordEntry) else {
                        return nil
                    }
                    return passwordData

                case .otherEncryption(let importTrustedKey, let importSecureKey):
                    // Password is encrypted with a different master key
                    // Select the correct pre-computed import key based on protection level
                    let importKey: SymmetricKey
                    switch protectionLevel {
                    case .normal:
                        importKey = importTrustedKey
                    case .confirm, .topSecret:
                        importKey = importSecureKey
                    }

                    guard let passwordData = Data(base64Encoded: passwordEntry),
                          let decryptedPassword = mainRepository.decrypt(passwordData, key: importKey),
                          let reencryptedPassword = mainRepository.encrypt(decryptedPassword, key: key) else {
                        return nil
                    }
                    return reencryptedPassword
                }
            }()
            
            let resolvedDomain: String? = {
                guard content.iconType == 0,
                      let uriIndex = content.iconUriIndex,
                      let uri = content.uris?[safe: uriIndex] else { return nil }
                return uriInteractor.extractDomain(from: uri.text)
            }()

            let iconType = passwordIconType(
                rawIconType: content.iconType,
                resolvedDomain: resolvedDomain,
                customImageUrl: content.customImageUrl,
                labelText: content.labelText,
                labelColor: content.labelColor,
                name: content.name
            )

            let uris = passwordURIs(from: content.uris, text: \.text, matcher: \.matcher)
            
            let loginContent = LoginItemData.Content(
                name: content.name,
                username: content.username,
                password: password,
                notes: content.notes?.sanitizeNotes(),
                iconType: iconType,
                uris: uris
            )
            
            return .login(.init(
                id: itemID,
                vaultId: vaultID,
                metadata: itemMetadata,
                name: content.name,
                content: loginContent
            ))
            
        default:
            let content: [String: Any] = {
                switch encryption {
                case .unencrypted:
                    // Encrypt plaintext secure fields with current vault key
                    return encryptSecureFields(in: exchangeLogin.content, contentType: contentType, using: key)

                case .currentEncryption:
                    // Fields are already encrypted with current vault key
                    return exchangeLogin.content

                case .otherEncryption(let importTrustedKey, let importSecureKey):
                    // Secure fields are encrypted with a different master key
                    // Select the correct pre-computed import key based on protection level
                    let importKey: SymmetricKey
                    switch protectionLevel {
                    case .normal:
                        importKey = importTrustedKey
                    case .topSecret, .confirm:
                        importKey = importSecureKey
                    }
                    return reencryptSecureFields(in: exchangeLogin.content, contentType: contentType, decryptionKey: importKey, encryptionKey: key)
                }
            }()
            
            guard let contentData = try? mainRepository.jsonEncoder.encode(AnyCodable(content)) else {
                return nil
            }

            let rawItem = RawItemData(
                id: itemID,
                vaultId: vaultID,
                metadata: itemMetadata,
                name: exchangeLogin.content[ExchangeVault.contentNameKey] as? String,
                contentType: contentType,
                contentVersion: exchangeLogin.contentVersion,
                content: contentData
            )
            
            return ItemData(rawItem)
        }
    }
    
    func encryptSecureFields(in content: [String: Any], contentType: ItemContentType, using key: SymmetricKey) -> [String: Any] {
        content.reduce(into: [String: Any]()) { result, keyValue in
            if contentType.isSecureField(key: keyValue.key) {
                if let stringValue = keyValue.value as? String, let data = stringValue.data(using: .utf8) {
                    result[keyValue.key] = mainRepository.encrypt(data, key: key)?.base64EncodedString()
                }
            } else {
                result[keyValue.key] = keyValue.value
            }
        }
    }

    func reencryptSecureFields(in content: [String: Any], contentType: ItemContentType, decryptionKey: SymmetricKey, encryptionKey: SymmetricKey) -> [String: Any] {
        content.reduce(into: [String: Any]()) { result, keyValue in
            if contentType.isSecureField(key: keyValue.key) {
                if let base64String = keyValue.value as? String,
                   let encryptedData = Data(base64Encoded: base64String),
                   let decryptedData = mainRepository.decrypt(encryptedData, key: decryptionKey),
                   let reencryptedData = mainRepository.encrypt(decryptedData, key: encryptionKey) {
                    result[keyValue.key] = reencryptedData.base64EncodedString()
                }
            } else {
                result[keyValue.key] = keyValue.value
            }
        }
    }

    /// Decodes JSON `content`, walks every `contentType.isSecureField(key:)` entry,
    /// runs `transform` on its `String` value, and re-encodes. Returns nil if the JSON
    /// is malformed, a secure field's value isn't a `String`, or `transform` returns nil
    /// (failed decrypt or encrypt).
    private func transformSecureFields(in content: Data, contentType: ItemContentType, transform: (String) -> String?) -> Data? {
        guard let dict = try? JSONSerialization.jsonObject(with: content) as? [String: Any] else { return nil }
        var result: [String: Any] = [:]
        for (key, value) in dict {
            if contentType.isSecureField(key: key) {
                guard let stringValue = value as? String, let transformed = transform(stringValue) else { return nil }
                result[key] = transformed
            } else {
                result[key] = value
            }
        }
        return try? JSONSerialization.data(withJSONObject: result)
    }

    /// Maps the exchange-format securityType integer (0/1/2) to the local `ItemProtectionLevel`.
    /// Shared between v1 and v2 login/item translation paths. Nil/unknown defaults to `.normal`.
    private func protectionLevel(fromSecurityType securityType: Int?) -> ItemProtectionLevel {
        switch securityType {
        case 0: .topSecret
        case 1: .confirm
        case 2: .normal
        default: .normal
        }
    }

    /// Builds a `PasswordIconType` from the raw exchange fields. Caller pre-resolves the
    /// domain string (when iconType == 0) since URI-array shape differs between v1/v2.
    private func passwordIconType(
        rawIconType: Int?,
        resolvedDomain: String?,
        customImageUrl: String?,
        labelText: String?,
        labelColor: String?,
        name: String?
    ) -> PasswordIconType {
        switch rawIconType {
        case 0:
            return .domainIcon(resolvedDomain)
        case 2:
            guard let urlString = customImageUrl, let url = URL(string: urlString) else {
                return .domainIcon(nil)
            }
            return .customIcon(url)
        default:
            let title = labelText ?? name.map { Config.defaultIconLabel(forName: $0) } ?? Config.defaultIconLabel
            let color = UIColor(hexString: labelColor)
            return .label(labelTitle: title, labelColor: color)
        }
    }

    /// Translates an array of exchange URIs to `[PasswordURI]`. Caller provides accessors
    /// for text and matcher since v1/v2 URI structs differ.
    private func passwordURIs<URIItem>(
        from uris: [URIItem]?,
        text: (URIItem) -> String,
        matcher: (URIItem) -> Int
    ) -> [PasswordURI]? {
        guard let uris, !uris.isEmpty else { return nil }
        return uris.map { item in
            PasswordURI(
                uri: text(item),
                match: {
                    switch matcher(item) {
                    case 0: .domain
                    case 1: .host
                    case 2: .startsWith
                    case 3: .exact
                    default: .domain
                    }
                }()
            )
        }
    }

    func exchangeTagToItemTagData(_ exchangeTag: ExchangeVault.ExchangeVaultItem.ExchangeTag, vaultID: VaultID) -> ItemTagData? {
        guard let tagID = ItemTagID(uuidString: exchangeTag.id) else { return nil }
        return ItemTagData(
            tagID: tagID,
            vaultID: vaultID,
            name: exchangeTag.name,
            color: .init(rawValue: exchangeTag.color),
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

    // MARK: - V1 Schema Support

    func exchangeV1LoginToItemData(_ exchangeLogin: ExchangeSchemaV1.ExchangeVault.ExchangeVaultItem.ExchangeLogin, vaultID: VaultID) -> ItemData? {
        guard let itemID = UUID(uuidString: exchangeLogin.id) else {
            return nil
        }

        let protectionLevel = protectionLevel(fromSecurityType: exchangeLogin.securityType)

        let itemMetadata = ItemMetadata(
            creationDate: Date(exportTimestamp: exchangeLogin.createdAt),
            modificationDate: Date(exportTimestamp: exchangeLogin.updatedAt),
            protectionLevel: protectionLevel,
            trashedStatus: .no,
            tagIds: exchangeLogin.tags?.compactMap { UUID(uuidString: $0) }
        )

        guard let key = mainRepository.getKey(isPassword: true, protectionLevel: protectionLevel, forVault: vaultID) else {
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

        let resolvedDomain: String? = {
            guard exchangeLogin.iconType == 0,
                  let uriIndex = exchangeLogin.iconUriIndex,
                  let uri = exchangeLogin.uris?[safe: uriIndex] else { return nil }
            return uriInteractor.extractDomain(from: uri.text)
        }()

        let iconType = passwordIconType(
            rawIconType: exchangeLogin.iconType,
            resolvedDomain: resolvedDomain,
            customImageUrl: exchangeLogin.customImageUrl,
            labelText: exchangeLogin.labelText,
            labelColor: exchangeLogin.labelColor,
            name: exchangeLogin.name
        )

        let uris = passwordURIs(from: exchangeLogin.uris, text: \.text, matcher: \.matcher)

        let loginContent = LoginItemData.Content(
            name: exchangeLogin.name,
            username: exchangeLogin.username,
            password: password,
            notes: exchangeLogin.notes?.sanitizeNotes(),
            iconType: iconType,
            uris: uris
        )

        return .login(.init(
            id: itemID,
            vaultId: vaultID,
            metadata: itemMetadata,
            name: exchangeLogin.name,
            content: loginContent
        ))
    }


    func extractDataV1(
        from logins: [String],
        tags: [String],
        deleted: [String],
        vaultID: VaultID,
        using key: SymmetricKey
    ) async -> ImportedDataPayload {
        Log("ImportInteractor - importing \(logins.count) v1 logins, \(tags.count) tags and \(deleted.count) deleted entries", module: .interactor)

        async let parsedItems: [ItemData] = decryptAndParse(logins, using: key) { [self] jsonData, decoder in
            let exchangeLogin = try decoder.decode(
                ExchangeSchemaV1.ExchangeVault.ExchangeVaultItem.ExchangeLogin.self,
                from: jsonData
            )
            return self.exchangeV1LoginToItemData(exchangeLogin, vaultID: vaultID)
        }

        async let parsedTags: [ItemTagData] = decryptAndParse(tags, using: key) { [self] jsonData, decoder in
            let exchangeTag = try decoder.decode(
                ExchangeVault.ExchangeVaultItem.ExchangeTag.self,
                from: jsonData
            )
            return self.exchangeTagToItemTagData(exchangeTag, vaultID: vaultID)
        }

        async let parsedDeleted: [DeletedItemData] = decryptAndParse(deleted, using: key) { [self] jsonData, decoder in
            let exchangeDeleted = try decoder.decode(
                ExchangeVault.ExchangeVaultItem.ExchangeDeletedItem.self,
                from: jsonData
            )
            return self.exchangeDeletedPasswordToDeletedPasswordData(exchangeDeleted, vaultID: vaultID)
        }

        let (resultItems, resultTags, resultDeleted) = await (parsedItems, parsedTags, parsedDeleted)
        Log("ImportInteractor - parsed \(resultItems.count) v1 logins, \(resultTags.count) tags and \(resultDeleted.count) deleted entries", module: .interactor)
        return (resultItems, resultTags, resultDeleted)
    }
}
