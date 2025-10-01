// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CryptoKit
import Common

protocol ConnectExportInteracting: AnyObject {
    func prepareItemForConnectExport(id: ItemID, encryptPasswordKey: (ItemProtectionLevel) -> SymmetricKey?, deviceId: UUID) async throws(ExportError) -> ConnectLogin
    func prepareItemsForConnectExport(encryptPasswordKey: SymmetricKey, deviceId: UUID) async throws(ExportError) -> Data
    func prepareTagsForConnectExport() async throws(ExportError) -> Data
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
    
    func prepareItemsForConnectExport(encryptPasswordKey: SymmetricKey, deviceId: UUID) async throws(ExportError) -> Data {
        guard let _ = self.mainRepository.selectedVault else {
            throw .noSelectedVault
        }
        
        let items = Task { @MainActor in
            mainRepository.listItems(options: .allNotTrashed)
                .filter { $0.protectionLevel != .topSecret }
                .compactMap { ItemData($0, decoder: mainRepository.jsonDecoder)?.asLoginItem }
        }
             
        let connectLogins = await items.value.map {
            itemToConnectLogin($0, deviceId: deviceId, excludeSecureValuesProtectionLevels: [.confirm], encryptPasswordKey: encryptPasswordKey)
        }
        
        do {
            return try self.mainRepository.jsonEncoder.encode(connectLogins)
        } catch {
            throw .jsonEncode(error: error)
        }
    }
    
    func prepareItemForConnectExport(id: ItemID, encryptPasswordKey: (ItemProtectionLevel) -> SymmetricKey?, deviceId: UUID) async throws(ExportError) -> ConnectLogin {
        let rawItem = Task { @MainActor in
            mainRepository.getItemEntity(itemID: id, checkInTrash: false)
        }
   
        guard let rawItem = await rawItem.value, let loginItem = ItemData(rawItem, decoder: mainRepository.jsonDecoder)?.asLoginItem else {
            throw .noItemsToExport
        }
        
        let connectLogin = itemToConnectLogin(loginItem, deviceId: deviceId, encryptPasswordKey: encryptPasswordKey(loginItem.protectionLevel))
        return connectLogin
    }
    
    func prepareTagsForConnectExport() async throws(ExportError) -> Data {
        let tags = tagInteractor.listAllTags()
            .map {
                ConnectTag(
                    id: $0.id.exportString(),
                    name: $0.name,
                    color: $0.color?.hexString,
                    position: $0.position,
                    updatedAt: $0.modificationDate.exportTimestamp
                )
            }
        
        do {
            return try self.mainRepository.jsonEncoder.encode(tags)
        } catch {
            throw .jsonEncode(error: error)
        }
    }
    
    private func itemToConnectLogin(
        _ item: LoginItemData,
        deviceId: UUID,
        excludeSecureValuesProtectionLevels: Set<ItemProtectionLevel> = [],
        encryptPasswordKey: SymmetricKey? = nil
    ) -> ConnectLogin {
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
            
            if let encryptPasswordKey,
               let nonce = mainRepository.generateRandom(byteCount: Config.Connect.passwordNonceByteCount),
               let decryptedPasswordData = decryptedPassword.data(using: .utf8),
               let encrypted = mainRepository.encrypt(decryptedPasswordData, key: encryptPasswordKey, nonce: nonce) {
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
    
    private func uriToConnectURI(uri: PasswordURI) -> ConnectLogin.ConnectURI {
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
}
