// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common
import CryptoKit

public enum ExportError: Error {
    case noPasswordsToExport
    case noSelectedVault
    case missingExternalKey
    case encryptionDef
    case jsonEncode(error: Error)
}

public protocol ExportInteracting: AnyObject {
    func preparePasswordsForExport(encrypt: Bool, exportIfEmpty: Bool, includeDeletedItems: Bool, completion: @escaping (Result<(Data, String), ExportError>) -> Void)
}

final class ExportInteractor {
    private let mainRepository: MainRepository
    private let itemsInteractor: ItemsInteracting
    private let tagInteractor: TagInteracting
    private let uriInteractor: URIInteracting
    private let queue: DispatchQueue
    private let writeQueue: DispatchQueue
    
    init(
        mainRepository: MainRepository,
        itemsInteractor: ItemsInteracting,
        tagInteractor: TagInteracting,
        uriInteractor: URIInteracting
    ) {
        self.mainRepository = mainRepository
        self.itemsInteractor = itemsInteractor
        self.tagInteractor = tagInteractor
        self.uriInteractor = uriInteractor
        self.queue = DispatchQueue(label: "ExportQueue", qos: .userInitiated, attributes: .concurrent)
        self.writeQueue = DispatchQueue(label: "ExportWriteArray", qos: .userInitiated)
    }
}

extension ExportInteractor: ExportInteracting {
        
    func preparePasswordsForExport(encrypt: Bool, exportIfEmpty: Bool, includeDeletedItems: Bool, completion: @escaping (Result<(Data, String), ExportError>) -> Void) {
        func end(_ result: Result<(Data, String), ExportError>) {
            DispatchQueue.main.async {
                completion(result)
            }
        }
        DispatchQueue.global(qos: .userInitiated).async {
            guard let vault = self.mainRepository.selectedVault else {
                end(.failure(.noSelectedVault))
                return
            }
            
            DispatchQueue.main.async {
                let passwords = self.mainRepository.listPasswords(options: .allNotTrashed).compactMap {
                    ItemData($0, decoder: self.mainRepository.jsonDecoder)?.asLoginItem
                }
                let tags = self.tagInteractor.listAllTags()
                let deleted = includeDeletedItems ? self.mainRepository.listDeletedItems(in: vault.vaultID, limit: nil) : []
                
                DispatchQueue.global(qos: .userInitiated).async {
                    guard exportIfEmpty || (!passwords.isEmpty || !deleted.isEmpty) else {
                        end(.failure(.noPasswordsToExport))
                        return
                    }
                    
                    let exchangeLogins = passwords.map { self.passwordToExchangeLogin($0) }
                    let exchangeDeleted = deleted.map { self.deletedToExchangeDeleted($0) }
                    let exchangeTags = tags.map { self.tagsToExchangeTags($0) }
                    let jsonEncoder = self.mainRepository.jsonEncoder
                    
                    if encrypt {
                        guard let key = self.mainRepository.cachedExternalKey else {
                            completion(.failure(.missingExternalKey))
                            return
                        }
                        
                        guard let seedHashHex = self.mainRepository.createSeedHashHexForExport(),
                              let reference = self.mainRepository.createReferenceForExport()
                        else {
                            end(.failure(.encryptionDef))
                            return
                        }
                        
                        self.prepareEncryptedLogins(
                            exchangeLogins: exchangeLogins,
                            exchangeDeleted: exchangeDeleted,
                            key: key
                        ) { [weak self] loginsEncrypted, loginsDeletedEncrypted in
                            guard let self else { return }
                            
                            let tagsEncrypted = prepareEncryptedTags(exchangeTags, key: key)
                            
                            let mainVault = self.mainVault(
                                vault,
                                logins: nil,
                                loginsEncrypted: loginsEncrypted,
                                loginsDeleted: nil,
                                loginsDeletedEncrypted: includeDeletedItems ? loginsDeletedEncrypted : nil,
                                tags: nil,
                                tagsEncrypted: tagsEncrypted
                            )
                            let exchangeVault = self.exchangeVault(vault: mainVault, encryption: exchangeEncryption(seedHashHex: seedHashHex, reference: reference))
                            
                            do {
                                let encoded = try jsonEncoder.encode(exchangeVault)
                                end(.success((encoded, vault.name)))
                            } catch {
                                end(.failure(.jsonEncode(error: error)))
                            }
                        }
                    } else {
                        let mainVault = self.mainVault(
                            vault,
                            logins: exchangeLogins,
                            loginsEncrypted: nil,
                            loginsDeleted: includeDeletedItems ? exchangeDeleted : nil,
                            loginsDeletedEncrypted: nil,
                            tags: exchangeTags,
                            tagsEncrypted: nil
                        )
                        let exchangeVault = self.exchangeVault(vault: mainVault, encryption: nil)
                        
                        do {
                            let encoded = try jsonEncoder.encode(exchangeVault)
                            end(.success((encoded, vault.name)))
                        } catch {
                            end(.failure(.jsonEncode(error: error)))
                        }
                    }
                }
            }
        }
    }
}

private extension ExportInteractor {
    
    func prepareEncryptedTags(_ tags: [ExchangeVault.ExchangeVaultItem.ExchangeTag], key: SymmetricKey) -> [String] {
        tags.compactMap { tag in
            guard let data = try? mainRepository.jsonEncoder.encode(tag) else {
                Log(
                    "Export Interactor - can't encode one of the tags for export",
                    module: .interactor,
                    severity: .error
                )
                return nil
            }
            guard let value = self.mainRepository.encrypt(data, key: key)?.base64EncodedString() else {
                Log(
                    "Export Interactor - can't encrypt one of the tags for export",
                    module: .interactor,
                    severity: .error
                )
                return nil
            }
            return value
        }
    }
    
    func prepareEncryptedLogins(
        exchangeLogins: [ExchangeVault.ExchangeVaultItem.ExchangeLogin],
        exchangeDeleted: [ExchangeVault.ExchangeVaultItem.ExchangeDeletedItem],
        key: SymmetricKey,
        completion: @escaping ([String], [String]) -> Void
    ) {
        func exp(_ pass: ExchangeVault.ExchangeVaultItem.ExchangeLogin) -> String? {
            let jsonEncoder = mainRepository.jsonEncoder
            guard let data = try? jsonEncoder.encode(pass) else {
                Log(
                    "Export Interactor - can't encode one of the passwords for export",
                    module: .interactor,
                    severity: .error
                )
                return nil
            }
            guard let value = self.mainRepository.encrypt(data, key: key)?.base64EncodedString() else {
                Log(
                    "Export Interactor - can't encrypt one of the passwords for export",
                    module: .interactor,
                    severity: .error
                )
                return nil
            }
            return value
        }
        
        if exchangeLogins.isEmpty {
            continuePreparataionOfEncryptedLogins(
                exchangeLogins: [],
                exchangeDeleted: exchangeDeleted,
                key: key,
                completion: completion
            )
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let group = DispatchGroup()
            
            var resultsPasswords: [String] = []
            
            for pass in exchangeLogins {
                group.enter()
                self.queue.async {
                    let result = exp(pass)
                    self.writeQueue.async {
                        if let result {
                            resultsPasswords.append(result)
                        }
                        group.leave()
                    }
                }
            }
            
            group.notify(queue: .global()) {
                self.continuePreparataionOfEncryptedLogins(
                    exchangeLogins: resultsPasswords,
                    exchangeDeleted: exchangeDeleted,
                    key: key,
                    completion: completion
                )
            }
        }
    }
    
    func continuePreparataionOfEncryptedLogins(
        exchangeLogins: [String],
        exchangeDeleted: [ExchangeVault.ExchangeVaultItem.ExchangeDeletedItem],
        key: SymmetricKey,
        completion: @escaping ([String], [String]) -> Void
    ) {
        func exp(_ deleted: ExchangeVault.ExchangeVaultItem.ExchangeDeletedItem) -> String? {
            let jsonEncoder = mainRepository.jsonEncoder
            guard let data = try? jsonEncoder.encode(deleted) else {
                Log(
                    "Export Interactor - can't encode one of the deleted password for export",
                    module: .interactor,
                    severity: .error
                )
                return nil
            }
            guard let value = self.mainRepository.encrypt(data, key: key)?.base64EncodedString() else {
                Log(
                    "Export Interactor - can't encrypt one of the deleted password for export",
                    module: .interactor,
                    severity: .error
                )
                return nil
            }
            return value
        }
        
        if exchangeDeleted.isEmpty {
            DispatchQueue.main.async {
                completion(exchangeLogins, [])
            }
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let group = DispatchGroup()
            var resultsDeleted: [String] = []
            
            for deleted in exchangeDeleted {
                group.enter()
                self.queue.async {
                    let result = exp(deleted)
                    self.writeQueue.async {
                        if let result {
                            resultsDeleted.append(result)
                        }
                        group.leave()
                    }
                }
            }
            
            group.notify(queue: .main) { completion(exchangeLogins, resultsDeleted) }
        }
    }
    
    func exchangeVault(
        vault: ExchangeVault.ExchangeVaultItem,
        encryption: ExchangeVault.ExchangeEncryption?
    ) -> ExchangeVault {
        ExchangeVault(
            schemaVersion: Config.schemaVersion,
            origin: origin(),
            encryption: encryption,
            vault: vault
        )
    }
    
    func mainVault(
        _ vault: VaultEncryptedData,
        logins: [ExchangeVault.ExchangeVaultItem.ExchangeLogin]?,
        loginsEncrypted: [String]?,
        loginsDeleted: [ExchangeVault.ExchangeVaultItem.ExchangeDeletedItem]?,
        loginsDeletedEncrypted: [String]?,
        tags: [ExchangeVault.ExchangeVaultItem.ExchangeTag]?,
        tagsEncrypted: [String]?
    ) -> ExchangeVault.ExchangeVaultItem {
        .init(
            id: vault.vaultID.exportString(),
            name: vault.name,
            createdAt: vault.createdAt.exportTimestamp,
            updatedAt: mainRepository.currentDate.exportTimestamp,
            logins: logins,
            loginsEncrypted: loginsEncrypted,
            tags: tags,
            tagsEncrypted: tagsEncrypted,
            itemsDeleted: loginsDeleted,
            itemsDeletedEncrypted: loginsDeletedEncrypted
        )
    }
    
    func origin() -> ExchangeVault.ExchangeVaultOrigin {
        .init(
            os: "ios",
            appVersionCode: 1,
            appVersionName: mainRepository.currentAppVersion,
            deviceName: mainRepository.deviceName,
            deviceId: mainRepository.deviceID
        )
    }
    
    func passwordToExchangeLogin(_ password: LoginItemData) -> ExchangeVault.ExchangeVaultItem.ExchangeLogin {
        let passwordDecrypted: String? = {
            guard let pass = password.password else {
                return nil
            }
            return itemsInteractor.decrypt(pass, isPassword: true, protectionLevel: password.protectionLevel)
        }()
        let securityType: Int = {
            switch password.protectionLevel {
            case .normal: 2
            case .confirm: 1
            case .topSecret: 0
            }
        }()
        var labelTitle: String?
        var labelColor: String?
        var iconURI: String?
        
        let iconType: Int = {
            switch password.iconType {
            case .domainIcon:
                return 0
            case .label(let labelTitleValue, let labelColorValue):
                labelTitle = labelTitleValue
                labelColor = labelColorValue?.hexString
                return 1
            case .customIcon(let iconURIValue):
                iconURI = iconURIValue.absoluteString
                return 2
            }
        }()
        
        let iconURIIndex: Int? = {
            switch password.iconType {
            case .domainIcon(let domain):
                return password.uris?.firstIndex(where: {
                    uriInteractor.extractDomain(from: $0.uri) == domain
                })
            default:
                return nil
            }
        }()
        
        return .init(
            id: password.id.exportString(),
            name: password.name,
            username: password.username,
            password: passwordDecrypted,
            notes: password.notes?.sanitizeNotes(),
            securityType: securityType,
            iconType: iconType,
            iconUriIndex: iconURIIndex,
            labelText: labelTitle,
            labelColor: labelColor,
            customImageUrl: iconURI,
            createdAt: password.creationDate.exportTimestamp,
            updatedAt: password.modificationDate.exportTimestamp,
            uris: password.uris?.map({ uriToExchangeURI(uri: $0) }) ?? [],
            tags: password.tagIds?.map { $0.exportString() }
        )
    }
    
    func deletedToExchangeDeleted(_ deleted: DeletedItemData) -> ExchangeVault.ExchangeVaultItem.ExchangeDeletedItem {
        let type: ExchangeVault.ExchangeVaultItem.ExchangeDeletedItem.DeletedItemType = {
            switch deleted.kind {
            case .login: return .login
            case .tag: return .tag
            }
        }()
        return .init(id: deleted.itemID.uuidString.lowercased(),
                     type: type.rawValue,
                     deletedAt: deleted.deletedAt.exportTimestamp)
    }
    
    func tagsToExchangeTags(_ tag: ItemTagData) -> ExchangeVault.ExchangeVaultItem.ExchangeTag {
        .init(
            id: tag.id.exportString(),
            name: tag.name,
            color: tag.color?.hexString,
            position: tag.position,
            updatedAt: tag.modificationDate.exportTimestamp
        )
    }
    
    func uriToExchangeURI(uri: PasswordURI) -> ExchangeVault.ExchangeVaultItem.ExchangeLogin.ExchangeURI {
        let matcher: Int = {
            switch uri.match {
            case .domain: 0
            case .host: 1
            case .startsWith: 2
            case .exact: 3
            }
        }()
        return .init(text: uri.uri, matcher: matcher)
    }
    
    func exchangeEncryption(seedHashHex: String, reference: String) -> ExchangeVault.ExchangeEncryption {
        .init(
            seedHash: seedHashHex,
            reference: reference,
            kdfSpec: exchangeKDFSpec()
        )
    }
    
    func exchangeKDFSpec() -> ExchangeVault.ExchangeEncryption.ExchangeKDFSpec {
        .init(
            type: Config.kdfSpec.algorithm.rawValue,
            hashLength: Config.kdfSpec.hashLength,
            memoryMb: Config.kdfSpec.memoryMB,
            iterations: Config.kdfSpec.iterations,
            parallelism: Config.kdfSpec.parallelism
        )
    }
}
