// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common
import CryptoKit

public enum ExportError: Error {
    case noItemsToExport
    case noSelectedVault
    case missingExternalKey
    case encryptionDef
    case jsonEncode(error: Error)
    case jsonDecode(error: Error?)
}

public protocol ExportInteracting: AnyObject {
    func prepareItemsForExport(encrypt: Bool, exportIfEmpty: Bool, includeDeletedItems: Bool, completion: @escaping (Result<(Data, String), ExportError>) -> Void)
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
        
    func prepareItemsForExport(encrypt: Bool, exportIfEmpty: Bool, includeDeletedItems: Bool, completion: @escaping (Result<(Data, String), ExportError>) -> Void) {
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
                let items = self.mainRepository.listEncryptedItems(in: vault.id)
                let tags = self.tagInteractor.listAllTags()
                let deleted = includeDeletedItems ? self.mainRepository.listDeletedItems(in: vault.vaultID, limit: nil) : []
                
                DispatchQueue.global(qos: .userInitiated).async {
                    guard exportIfEmpty || (!items.isEmpty || !deleted.isEmpty) else {
                        end(.failure(.noItemsToExport))
                        return
                    }
                    
                    let exchangeLogins = items.compactMap { self.itemToExchangeItems($0, encrypt: encrypt) }
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
                        
                        self.prepareEncryptedItems(
                            exchangeItems: exchangeLogins,
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
    
    func prepareEncryptedItems(
        exchangeItems: [ExchangeVault.ExchangeVaultItem.ExchangeItem],
        exchangeDeleted: [ExchangeVault.ExchangeVaultItem.ExchangeDeletedItem],
        key: SymmetricKey,
        completion: @escaping ([String], [String]) -> Void
    ) {
        func exp(_ pass: ExchangeVault.ExchangeVaultItem.ExchangeItem) -> String? {
            let jsonEncoder = mainRepository.jsonEncoder
            guard let data = try? jsonEncoder.encode(pass) else {
                Log(
                    "Export Interactor - can't encode one of the items for export",
                    module: .interactor,
                    severity: .error
                )
                return nil
            }
            guard let value = self.mainRepository.encrypt(data, key: key)?.base64EncodedString() else {
                Log(
                    "Export Interactor - can't encrypt one of the items for export",
                    module: .interactor,
                    severity: .error
                )
                return nil
            }
            return value
        }
        
        if exchangeItems.isEmpty {
            continuePreparataionOfEncryptedItems(
                exchangeItems: [],
                exchangeDeleted: exchangeDeleted,
                key: key,
                completion: completion
            )
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let group = DispatchGroup()
            
            var resultsPasswords: [String] = []
            
            for pass in exchangeItems {
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
                self.continuePreparataionOfEncryptedItems(
                    exchangeItems: resultsPasswords,
                    exchangeDeleted: exchangeDeleted,
                    key: key,
                    completion: completion
                )
            }
        }
    }
    
    func continuePreparataionOfEncryptedItems(
        exchangeItems: [String],
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
                completion(exchangeItems, [])
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
            
            group.notify(queue: .main) { completion(exchangeItems, resultsDeleted) }
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
        logins: [ExchangeVault.ExchangeVaultItem.ExchangeItem]?,
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
            items: logins,
            itemsEncrypted: loginsEncrypted,
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
    
    func itemToExchangeItems(_ item: ItemEncryptedData, encrypt: Bool) -> ExchangeVault.ExchangeVaultItem.ExchangeItem? {
        guard let content = itemsInteractor.decryptData(item.content, isSecureField: false, protectionLevel: item.protectionLevel) else {
            return nil
        }
        
        let exportContent: [String: Any]? = {
            switch item.contentType {
            case .login:
                guard let passwordContent = try? mainRepository.jsonDecoder.decode(LoginItemData.Content.self, from: content) else {
                    return nil
                }
                
                var labelTitle: String?
                var labelColor: String?
                var iconURI: String?
                
                let iconType: Int = {
                    switch passwordContent.iconType {
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
                    switch passwordContent.iconType {
                    case .domainIcon(let domain):
                        return passwordContent.uris?.firstIndex(where: {
                            uriInteractor.extractDomain(from: $0.uri) == domain
                        })
                    default:
                        return nil
                    }
                }()
                
                let passwordValue: String? = {
                    if let passwordValue = passwordContent.password {
                        if encrypt {
                            return passwordValue.base64EncodedString()
                        } else {
                            return itemsInteractor.decrypt(passwordValue, isSecureField: true, protectionLevel: item.protectionLevel)
                        }
                    }
                    return nil
                }()
                
                let content = ExchangeVault.ExchangeVaultItem.ExchangeItem.ExchangeLoginContent(
                    name: passwordContent.name,
                    username: passwordContent.username,
                    password: passwordValue,
                    notes: passwordContent.notes,
                    iconType: iconType,
                    iconUriIndex: iconURIIndex,
                    labelText: labelTitle,
                    labelColor: labelColor,
                    customImageUrl: iconURI,
                    uris: passwordContent.uris?.map({ uriToExchangeURI(uri: $0) }) ?? []
                )
                
                guard let data = try? mainRepository.jsonEncoder.encode(content) else {
                    return nil
                }
                return try? mainRepository.jsonDecoder.decode(AnyCodable.self, from: data).value as? [String: Any]
            default:
                guard let contentDict = try? mainRepository.jsonDecoder.decode(AnyCodable.self, from: content).value as? [String: Any] else {
                    return nil
                }
                
                if encrypt {
                    return contentDict
                } else {
                    guard let key = mainRepository.getKey(isPassword: true, protectionLevel: item.protectionLevel) else {
                        return nil
                    }
                    return decryptSecureFields(in: contentDict, contentType: item.contentType, using: key)
                }
            }
        }()
        
        guard let exportContent else {
            return nil
        }

        return .init(
            id: item.itemID.exportString(),
            contentType: item.contentType.rawValue,
            contentVersion: item.contentVersion,
            content: exportContent,
            securityType: item.protectionLevel.intValue,
            createdAt: item.creationDate.exportTimestamp,
            updatedAt: item.modificationDate.exportTimestamp,
            tags: item.tagIds?.map { $0.exportString() }
        )
    }
    
    private func decryptSecureFields(in content: [String: Any], contentType: ItemContentType, using key: SymmetricKey) -> [String: Any] {
        content.reduce(into: [String: Any]()) { result, keyValue in
            if contentType.isSecureField(key: keyValue.key) {
                if let stringValue = keyValue.value as? String, let data = Data(base64Encoded: stringValue), let decryptedData = mainRepository.decrypt(data, key: key) {
                    result[keyValue.key] = String(data: decryptedData, encoding: .utf8)
                }
            } else {
                result[keyValue.key] = keyValue.value
            }
        }
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
    
    func uriToExchangeURI(uri: PasswordURI) -> ExchangeVault.ExchangeVaultItem.ExchangeItem.ExchangeURI {
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
