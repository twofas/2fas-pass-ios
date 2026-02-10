// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CryptoKit
import Common

struct ConnectItemExportOptions: OptionSet {
    let rawValue: Int
    
    init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    static let includeUnencryptedFields = ConnectItemExportOptions(rawValue: 1 << 0)
    static let includeSecureFields = ConnectItemExportOptions(rawValue: 2 << 0)
    
    static let allFields: ConnectItemExportOptions = [.includeUnencryptedFields, .includeSecureFields]
}

typealias ConnectItemExportEncryptionKeyProvider = (ItemProtectionLevel) -> SymmetricKey?
typealias ConnectItemExportOptionsProvider = (ItemData) -> ConnectItemExportOptions

protocol ConnectExportInteracting: AnyObject {
    
    // Common
    @MainActor
    func prepareTagsForConnectExport() async throws(ExportError) -> [ConnectTag]
    
    // Scheme V1
    
    func prepareItemForConnectExport(
        id: ItemID,
        deviceId: UUID,
        secureFieldEncryptionKeyProvider: ConnectItemExportEncryptionKeyProvider
    ) async throws(ExportError) -> ConnectSchemaV1.ConnectLogin
    
    func prepareItemsForConnectExport(
        deviceId: UUID,
        secureFieldEncryptionKeyProvider: ConnectItemExportEncryptionKeyProvider
    ) async throws(ExportError) -> [ConnectSchemaV1.ConnectLogin]
    
    // Scheme V2
    
    func prepareVaultsForConnectExport(
        secureFieldEncryptionKeyProvider: ConnectItemExportEncryptionKeyProvider
    ) async -> [ConnectSchemaV2.ConnectVault]
    
    func prepareItemForConnectExport(
        id: ItemID,
        options: ConnectItemExportOptionsProvider,
        secureFieldEncryptionKeyProvider: ConnectItemExportEncryptionKeyProvider
    ) async throws(ExportError) -> ConnectSchemaV2.ConnectItem?
}

final class ConnectExportInteractor: ConnectExportInteracting {
    
    private let mainRepository: MainRepository
    private let itemsInteractor: ItemsInteracting
    private let tagInteractor: TagInteracting
    private let uriInteractor: URIInteracting
    
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
    }
    
    // MARK: - Common
    
    @MainActor
    func prepareTagsForConnectExport() throws(ExportError) -> [ConnectTag] {
        tagInteractor.listAllTags().map {
            ConnectTag(
                id: $0.id.exportString(),
                name: $0.name,
                color: $0.color.rawValue,
                position: $0.position,
                updatedAt: $0.modificationDate.exportTimestamp
            )
        }
    }
    
    // MARK: - Scheme v1
    
    func prepareItemsForConnectExport(deviceId: UUID, secureFieldEncryptionKeyProvider: ConnectItemExportEncryptionKeyProvider) async throws(ExportError) -> [ConnectSchemaV1.ConnectLogin] {
        guard mainRepository.selectedVault != nil else {
            throw .noSelectedVault
        }
        
        let items = Task { @MainActor in
            mainRepository.listItems(options: .allNotTrashed)
                .filter { $0.protectionLevel != .topSecret }
                .compactMap { $0.asLoginItem }
        }
        
        let connectLogins = await items.value.map { item in
            itemToConnectLogin(
                item,
                deviceId: deviceId,
                excludeSecureValuesProtectionLevels: [.confirm],
                secureFieldEncryptionKey: secureFieldEncryptionKeyProvider(item.protectionLevel)
            )
        }
        
        return connectLogins
    }
    
    func prepareItemForConnectExport(id: ItemID, deviceId: UUID, secureFieldEncryptionKeyProvider: ConnectItemExportEncryptionKeyProvider) async throws(ExportError) -> ConnectSchemaV1.ConnectLogin {
        let itemDataTask = Task { @MainActor in
            mainRepository.getItemEntity(itemID: id, checkInTrash: false)
        }
        
        guard let itemData = await itemDataTask.value, let loginItem = itemData.asLoginItem else {
            throw .noItemsToExport
        }
        
        return itemToConnectLogin(
            loginItem,
            deviceId: deviceId,
            secureFieldEncryptionKey: secureFieldEncryptionKeyProvider(loginItem.protectionLevel)
        )
    }
    
    // MARK: - Scheme v2
    
    func prepareVaultsForConnectExport(secureFieldEncryptionKeyProvider: ConnectItemExportEncryptionKeyProvider) async -> [ConnectSchemaV2.ConnectVault] {
        struct VaultSnapshot {
            let vault: VaultEncryptedData
            let tags: [ItemTagData]
            let items: [ItemData]
        }

        let snapshots = await MainActor.run { () -> [VaultSnapshot] in
            let vaults = mainRepository.listEncryptedVaults()
            let tagsByVault = Dictionary(grouping: tagInteractor.listAllTags(), by: \.vaultID)
            let itemsByVault = Dictionary(
                grouping: itemsInteractor.listItems(
                    searchPhrase: nil,
                    tagId: nil,
                    vaultId: nil,
                    contentTypes: .allKnownTypes,
                    protectionLevel: nil,
                    sortBy: .az,
                    trashed: .no
                )
                .filter { $0.protectionLevel != .topSecret },
                by: \.vaultId
            )

            return vaults.map { vault in
                return VaultSnapshot(
                    vault: vault,
                    tags: tagsByVault[vault.vaultID] ?? [],
                    items: itemsByVault[vault.vaultID] ?? []
                )
            }
        }

        return snapshots.map { snapshot in
            let connectTags = snapshot.tags.map {
                ConnectTag(
                    id: $0.id.exportString(),
                    name: $0.name,
                    color: $0.color.rawValue,
                    position: $0.position,
                    updatedAt: $0.modificationDate.exportTimestamp
                )
            }

            var connectItems: [ConnectSchemaV2.ConnectItem] = []
            connectItems.reserveCapacity(snapshot.items.count)

            for item in snapshot.items {
                do {
                    let connectItem = try makeConnectItem(
                        from: item,
                        optionsProvider: { item in
                            switch item.protectionLevel {
                            case .normal:
                                return .allFields
                            case .confirm:
                                return .includeUnencryptedFields
                            case .topSecret:
                                return []
                            }
                        },
                        secureFieldEncryptionKeyProvider: secureFieldEncryptionKeyProvider
                    )
                    connectItems.append(connectItem)
                } catch {
                    Log(
                        "Connect export: failed to prepare item \(item.id.exportString()) for vault \(snapshot.vault.vaultID.exportString())",
                        module: .connect,
                        severity: .error
                    )
                }
            }

            return ConnectSchemaV2.ConnectVault(
                id: snapshot.vault.id.exportString(),
                name: snapshot.vault.name,
                items: connectItems,
                tags: connectTags
            )
        }
    }
    
    func prepareItemForConnectExport(
        id: ItemID,
        options: ConnectItemExportOptionsProvider,
        secureFieldEncryptionKeyProvider: ConnectItemExportEncryptionKeyProvider
    ) async throws(ExportError) -> ConnectSchemaV2.ConnectItem? {
        let item = await MainActor.run {
            mainRepository.getItemEntity(itemID: id, checkInTrash: false)
        }
        
        guard let item else {
            throw .noItemsToExport
        }
        
        guard item.protectionLevel != .topSecret else {
            return nil
        }
        
        return try makeConnectItem(from: item,
                                   optionsProvider: options,
                                   secureFieldEncryptionKeyProvider: secureFieldEncryptionKeyProvider)
    }
}

private extension ConnectExportInteractor {
    
    // MARK: - Common (Helpers)
    
    func uriToConnectURI(uri: PasswordURI) -> ConnectURI {
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
    
    // MARK: - Scheme v1 (Helpers)
    
    func itemToConnectLogin(
        _ item: LoginItemData,
        deviceId: UUID,
        excludeSecureValuesProtectionLevels: Set<ItemProtectionLevel> = [],
        secureFieldEncryptionKey: SymmetricKey? = nil
    ) -> ConnectSchemaV1.ConnectLogin {
        let passwordExported: String? = {
            guard excludeSecureValuesProtectionLevels.contains(item.protectionLevel) == false else {
                return nil
            }
            
            guard let pass = item.password else {
                return nil
            }
            
            guard let decryptedPassword = itemsInteractor.decrypt(pass, isSecureField: true, protectionLevel: item.protectionLevel) else {
                return nil
            }
            
            if let secureFieldEncryptionKey,
               let nonce = mainRepository.generateRandom(byteCount: Config.Connect.secureFieldNonceByteCount),
               let decryptedPasswordData = decryptedPassword.data(using: .utf8),
               let encrypted = mainRepository.encrypt(decryptedPasswordData, key: secureFieldEncryptionKey, nonce: nonce) {
                return encrypted.base64EncodedString()
            } else {
                return nil
            }
        }()
        
        let securityType: Int = {
            switch item.protectionLevel {
            case .normal: 2
            case .confirm: 1
            case .topSecret: 0
            }
        }()
        
        var labelTitle: String?
        var labelColor: String?
        var customImageUrl: String?
        
        let iconType: Int = {
            switch item.iconType {
            case .domainIcon:
                return 0
            case .label(let labelTitleValue, let labelColorValue):
                labelTitle = labelTitleValue
                labelColor = labelColorValue?.hexString
                return 1
            case .customIcon(let iconURIValue):
                customImageUrl = iconURIValue.absoluteString
                return 2
            }
        }()
        
        let iconURIIndex: Int? = {
            switch item.iconType {
            case .domainIcon(let domain):
                return item.uris?.firstIndex(where: {
                    uriInteractor.extractDomain(from: $0.uri) == domain
                })
            default:
                return nil
            }
        }()
        
        return .init(
            id: item.id.exportString(),
            name: item.name,
            username: item.username,
            password: passwordExported,
            notes: item.notes?.sanitizeNotes(),
            securityType: securityType,
            iconType: iconType,
            iconUriIndex: iconURIIndex,
            labelText: labelTitle,
            labelColor: labelColor,
            customImageUrl: customImageUrl,
            createdAt: item.creationDate.exportTimestamp,
            updatedAt: item.modificationDate.exportTimestamp,
            uris: item.uris?.map({ uriToConnectURI(uri: $0) }) ?? [],
            tags: item.tagIds?.map { $0.exportString() },
            deviceId: deviceId
        )
    }
    
    // MARK: - Scheme v2 (Helpers)
    
    func makeConnectItem(from item: ItemData,
                         optionsProvider: ConnectItemExportOptionsProvider,
                         secureFieldEncryptionKeyProvider: ConnectItemExportEncryptionKeyProvider
    ) throws(ExportError) -> ConnectSchemaV2.ConnectItem {
        let encryptedContent = try makeEncryptedItemContent(from: item,
                                                            options: optionsProvider(item),
                                                            secureFieldEncryptionKeyProvider: secureFieldEncryptionKeyProvider)
        
        return ConnectSchemaV2.ConnectItem(
            id: item.id.exportString(),
            vaultId: item.vaultId.exportString(),
            contentType: item.contentType.rawValue,
            contentVersion: item.contentVersion,
            content: encryptedContent,
            securityType: item.protectionLevel.intValue,
            createdAt: item.creationDate.exportTimestamp,
            updatedAt: item.modificationDate.exportTimestamp,
            tags: item.tagIds?.map { $0.exportString() }
        )
    }
    
    func makeEncryptedItemContent(
        from item: ItemData,
        options: ConnectItemExportOptions,
        secureFieldEncryptionKeyProvider: ConnectItemExportEncryptionKeyProvider
    ) throws(ExportError) -> [String: Any] {
        switch item {
        case .login(let loginItem):
            var labelTitle: String?
            var labelColor: String?
            var customImageUrl: String?
            
            let iconType: Int? = {
                guard options.contains(.includeUnencryptedFields) else {
                    return nil
                }
                
                switch loginItem.iconType {
                case .domainIcon:
                    return 0
                case .label(let labelTitleValue, let labelColorValue):
                    labelTitle = labelTitleValue
                    labelColor = labelColorValue?.hexString
                    return 1
                case .customIcon(let iconURIValue):
                    customImageUrl = iconURIValue.absoluteString
                    return 2
                }
            }()
            
            let iconURIIndex: Int? = {
                guard options.contains(.includeUnencryptedFields) else {
                    return nil
                }
                
                switch loginItem.iconType {
                case .domainIcon(let domain):
                    return loginItem.uris?.firstIndex(where: {
                        uriInteractor.extractDomain(from: $0.uri) == domain
                    })
                default:
                    return nil
                }
            }()
            
            let passwordEnc: String? = {
                if options.contains(.includeSecureFields),
                   let passwordValue = loginItem.password,
                   let decryptKey = mainRepository.getKey(isPassword: true, protectionLevel: item.protectionLevel),
                   let decryptedValue = mainRepository.decrypt(passwordValue, key: decryptKey),
                   let nonce = mainRepository.generateRandom(byteCount: Config.Connect.secureFieldNonceByteCount),
                   let encryptKey = secureFieldEncryptionKeyProvider(item.protectionLevel),
                   let encrypted = mainRepository.encrypt(decryptedValue, key: encryptKey, nonce: nonce) {
                    return encrypted.base64EncodedString()
                }
                return nil
            }()
            
            let content = ConnectSchemaV2.ConnectItem.ConnectLoginContent(
                name: options.contains(.includeUnencryptedFields) ? loginItem.name : nil,
                username: options.contains(.includeUnencryptedFields) ? loginItem.username : nil,
                password: options.contains(.includeSecureFields) ? passwordEnc : nil,
                notes:  options.contains(.includeUnencryptedFields) ? loginItem.notes : nil,
                iconType:  options.contains(.includeUnencryptedFields) ? iconType : nil,
                iconUriIndex:  options.contains(.includeUnencryptedFields) ? iconURIIndex : nil,
                labelText:  options.contains(.includeUnencryptedFields) ? labelTitle : nil,
                labelColor: options.contains(.includeUnencryptedFields) ? labelColor : nil,
                customImageUrl: options.contains(.includeUnencryptedFields) ? customImageUrl : nil,
                uris:  options.contains(.includeUnencryptedFields) ? loginItem.uris?.map({ uriToConnectURI(uri: $0) }) : nil
            )
            
            let data: Data
            do {
                data = try mainRepository.jsonEncoder.encode(content)
            } catch {
                throw .jsonEncode(error: error)
            }

            do {
                guard let result = try mainRepository.jsonDecoder.decode(AnyCodable.self, from: data).value as? [String: Any] else {
                    throw ExportError.jsonDecode(error: nil)
                }
                return result
            } catch {
                throw .jsonDecode(error: error)
            }
            
        default:
            let contentData = try encodeContent(from: item)
            
            guard let contentDict = try decodeContent(contentData) else {
                throw ExportError.jsonDecode(error: nil)
            }
            
            return contentDict.reduce(into: [String: Any]()) { result, keyValue in
                if item.contentType.isSecureField(key: keyValue.key) {
                    if options.contains(.includeSecureFields),
                       let stringValue = keyValue.value as? String,
                       let data = Data(base64Encoded: stringValue),
                       let decryptedData = itemsInteractor.decryptData(data, isSecureField: true, protectionLevel: item.protectionLevel),
                       let nonce = mainRepository.generateRandom(byteCount: Config.Connect.secureFieldNonceByteCount),
                       let encryptKey = secureFieldEncryptionKeyProvider(item.protectionLevel),
                       let encyptedData = mainRepository.encrypt(decryptedData, key: encryptKey, nonce: nonce)
                    {
                        result[keyValue.key] = encyptedData.base64EncodedString()
                    }
                } else if options.contains(.includeUnencryptedFields) {
                    result[keyValue.key] = keyValue.value
                }
            }
        }
    }
    
    func reencryptSecureFields(in content: [String: Any], key encryptKey: SymmetricKey, contentType: ItemContentType) -> [String: Any] {
        Dictionary(uniqueKeysWithValues: content
            .compactMap { key, value in
                if contentType.isSecureField(key: key) {
                    guard let encryptedData = value as? Data,
                          let decryptKey = mainRepository.getKey(isPassword: true, protectionLevel: .normal),
                          let decryptedValue = mainRepository.decrypt(encryptedData, key: decryptKey),
                          let nonce = mainRepository.generateRandom(byteCount: Config.Connect.secureFieldNonceByteCount),
                          let encrypted = mainRepository.encrypt(decryptedValue, key: encryptKey, nonce: nonce) else {
                        return nil
                    }
                    return (key, encrypted.base64EncodedString())
                } else {
                    return(key, value)
                }
            }
        )
    }
    
    func encodeContent(from item: ItemData) throws(ExportError) -> Data {
        do {
            return try item.encodeContent(using: mainRepository.jsonEncoder)
        } catch {
            throw .jsonEncode(error: error)
        }
    }
    
    func decodeContent(_ contentData: Data) throws(ExportError) -> [String: Any]? {
        do {
            return try mainRepository.jsonDecoder.decode(AnyCodable.self, from: contentData).value as? [String: Any]
        } catch {
            throw .jsonDecode(error: error)
        }
    }
}
