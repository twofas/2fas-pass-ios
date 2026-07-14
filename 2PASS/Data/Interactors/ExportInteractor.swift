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
    func prepareItemsForExport(vaultID: VaultID, encrypt: Bool, exportIfEmpty: Bool, includeDeletedItems: Bool) async throws(ExportError) -> ExchangeVault
}

final class ExportInteractor {
    private let mainRepository: MainRepository
    private let vaultsInteractor: VaultsInteracting
    private let itemsInteractor: ItemsInteracting
    private let tagInteractor: TagInteracting
    private let uriInteractor: URIInteracting

    init(
        mainRepository: MainRepository,
        vaultsInteractor: VaultsInteracting,
        itemsInteractor: ItemsInteracting,
        tagInteractor: TagInteracting,
        uriInteractor: URIInteracting
    ) {
        self.mainRepository = mainRepository
        self.vaultsInteractor = vaultsInteractor
        self.itemsInteractor = itemsInteractor
        self.tagInteractor = tagInteractor
        self.uriInteractor = uriInteractor
    }
}

extension ExportInteractor: ExportInteracting {

    func prepareItemsForExport(
        vaultID: VaultID,
        encrypt: Bool,
        exportIfEmpty: Bool,
        includeDeletedItems: Bool
    ) async throws(ExportError) -> ExchangeVault {
        guard let vault = vaultsInteractor.vault(for: vaultID) else {
            throw .noSelectedVault
        }

        let (items, tags, deleted) = await MainActor.run {
            let items = mainRepository.listEncryptedItems(in: vaultID)
                .filter { $0.trashedStatus == .no }
            let tags = tagInteractor.listAllTags()
            let deleted = includeDeletedItems
                ? mainRepository.listDeletedItems(in: vaultID, limit: nil)
                : []
            return (items, tags, deleted)
        }

        guard exportIfEmpty || !items.isEmpty || !deleted.isEmpty else {
            throw .noItemsToExport
        }

        let exchangeLogins = items.compactMap { itemToExchangeItems($0, encrypt: encrypt, vaultID: vaultID) }
        let exchangeDeleted = deleted.map { deletedToExchangeDeleted($0) }
        let exchangeTags = tags.map { tagsToExchangeTags($0) }

        if encrypt {
            guard let key = mainRepository.cachedExternalKey(forVault: vaultID) else {
                throw .missingExternalKey
            }
            guard let seedHashHex = mainRepository.createSeedHashHexForExport(forVault: vaultID),
                  let reference = mainRepository.createReferenceForExport(forVault: vaultID)
            else {
                throw .encryptionDef
            }

            let loginsEncrypted = encryptItems(exchangeLogins, key: key)
            let loginsDeletedEncrypted = encryptDeletedItems(exchangeDeleted, key: key)
            let tagsEncrypted = prepareEncryptedTags(exchangeTags, key: key)

            let vaultItem = mainVault(
                vault,
                logins: nil,
                loginsEncrypted: loginsEncrypted,
                loginsDeleted: nil,
                loginsDeletedEncrypted: includeDeletedItems ? loginsDeletedEncrypted : nil,
                tags: nil,
                tagsEncrypted: tagsEncrypted
            )
            return exchangeVault(
                vault: vaultItem,
                encryption: exchangeEncryption(seedHashHex: seedHashHex, reference: reference)
            )
        } else {
            let vaultItem = mainVault(
                vault,
                logins: exchangeLogins,
                loginsEncrypted: nil,
                loginsDeleted: includeDeletedItems ? exchangeDeleted : nil,
                loginsDeletedEncrypted: nil,
                tags: exchangeTags,
                tagsEncrypted: nil
            )
            return exchangeVault(vault: vaultItem, encryption: nil)
        }
    }
}

private extension ExportInteractor {

    func encryptItems(
        _ items: [ExchangeVault.ExchangeVaultItem.ExchangeItem],
        key: SymmetricKey
    ) -> [String] {
        items.compactMap { item in
            guard let data = try? mainRepository.jsonEncoder.encode(item) else {
                Log(
                    "Export Interactor - can't encode one of the items for export",
                    module: .interactor,
                    severity: .error
                )
                return nil
            }
            guard let value = mainRepository.encrypt(data, key: key)?.base64EncodedString() else {
                Log(
                    "Export Interactor - can't encrypt one of the items for export",
                    module: .interactor,
                    severity: .error
                )
                return nil
            }
            return value
        }
    }

    func encryptDeletedItems(
        _ items: [ExchangeVault.ExchangeVaultItem.ExchangeDeletedItem],
        key: SymmetricKey
    ) -> [String] {
        items.compactMap { item in
            guard let data = try? mainRepository.jsonEncoder.encode(item) else {
                Log(
                    "Export Interactor - can't encode one of the deleted password for export",
                    module: .interactor,
                    severity: .error
                )
                return nil
            }
            guard let value = mainRepository.encrypt(data, key: key)?.base64EncodedString() else {
                Log(
                    "Export Interactor - can't encrypt one of the deleted password for export",
                    module: .interactor,
                    severity: .error
                )
                return nil
            }
            return value
        }
    }

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
            guard let value = mainRepository.encrypt(data, key: key)?.base64EncodedString() else {
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
        _ vault: VaultData,
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

    func itemToExchangeItems(_ item: ItemEncryptedData, encrypt: Bool, vaultID: VaultID) -> ExchangeVault.ExchangeVaultItem.ExchangeItem? {
        guard let content = itemsInteractor.decryptData(item.content, isSecureField: false, protectionLevel: item.protectionLevel, vaultID: vaultID) else {
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
                            return itemsInteractor.decrypt(passwordValue, isSecureField: true, protectionLevel: item.protectionLevel, vaultID: vaultID)
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
                    guard let key = mainRepository.getKey(isPassword: true, protectionLevel: item.protectionLevel, forVault: vaultID) else {
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
            color: tag.color.rawValue,
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
