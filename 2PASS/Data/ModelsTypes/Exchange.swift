// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public typealias ExchangeVault = ExchangeSchemaV2.ExchangeVault

enum ExchangeError: Error {
    case mismatchSchemaVersion(Int, expected: Int)
}

public enum ExchangeVaultVersioned {
    case v1(ExchangeSchemaV1.ExchangeVault)
    case v2(ExchangeSchemaV2.ExchangeVault)

    public var encryption: ExchangeCommon.ExchangeEncryption? {
        switch self {
        case .v1(let vault):
            return vault.encryption
        case .v2(let vault):
            return vault.encryption
        }
    }

    public var summary: (date: Date, vaultName: String, deviceName: String?, itemsCount: Int) {
        switch self {
        case .v1(let vault):
            return (
                date: Date(exportTimestamp: vault.vault.updatedAt),
                vaultName: vault.vault.name,
                deviceName: vault.origin.deviceName,
                itemsCount: vault.itemsCount
            )
        case .v2(let vault):
            return vault.summary
        }
    }

    public var vaultID: String {
        switch self {
        case .v1(let vault):
            return vault.vault.id
        case .v2(let vault):
            return vault.vault.id
        }
    }

    public var deviceId: UUID? {
        switch self {
        case .v1(let vault):
            return vault.origin.deviceId
        case .v2(let vault):
            return vault.origin.deviceId
        }
    }

    public var hasServices: Bool {
        switch self {
        case .v1(let vault):
            return vault.hasServices
        case .v2(let vault):
            return vault.hasServices
        }
    }
    
    public var hasUnencryptedServices: Bool {
        switch self {
        case .v1(let vault):
            return vault.vault.logins?.isEmpty == false || vault.vault.tags?.isEmpty == false || vault.vault.itemsDeleted?.isEmpty == false
        case .v2(let vault):
            return vault.vault.items?.isEmpty == false || vault.vault.tags?.isEmpty == false || vault.vault.itemsDeleted?.isEmpty == false
        }
    }

    public struct VaultMetadata {
        public let id: String
        public let createdAt: Int?
        public let updatedAt: Int
        public let name: String
    }

    public var vault: VaultMetadata {
        switch self {
        case .v1(let exchangeVault):
            return VaultMetadata(
                id: exchangeVault.vault.id,
                createdAt: exchangeVault.vault.createdAt,
                updatedAt: exchangeVault.vault.updatedAt,
                name: exchangeVault.vault.name
            )
        case .v2(let exchangeVault):
            return VaultMetadata(
                id: exchangeVault.vault.id,
                createdAt: exchangeVault.vault.createdAt,
                updatedAt: exchangeVault.vault.updatedAt,
                name: exchangeVault.vault.name
            )
        }
    }
    
    public var itemsDeleted: [ExchangeCommon.ExchangeDeletedItem] {
        switch self {
        case .v1(let v1Vault):
            guard let items = v1Vault.vault.itemsDeleted else {
                return []
            }
            return items
        case .v2(let v2Vault):
            guard let items = v2Vault.vault.itemsDeleted else {
                return []
            }
            return items
        }
    }
    
    public var tags: [ExchangeCommon.ExchangeTag] {
        switch self {
        case .v1(let v1Vault):
            guard let items = v1Vault.vault.tags else {
                return []
            }
            return items
        case .v2(let v2Vault):
            guard let items = v2Vault.vault.tags else {
                return []
            }
            return items
        }
    }
}

// MARK: - Common Types

public enum ExchangeCommon {

    public struct ExchangeVaultOrigin: Codable {
        let os: String
        let appVersionCode: Int
        let appVersionName: String
        let deviceName: String
        let deviceId: UUID?
    }

    public struct ExchangeEncryption: Codable {
        public struct ExchangeKDFSpec: Codable {
            let type: String?
            let hashLength: Int?
            let memoryMb: Int?
            let iterations: Int?
            let parallelism: Int?
        }

        public let seedHash: String
        public let reference: String
        public let kdfSpec: ExchangeKDFSpec
    }

    public struct ExchangeDeletedItem: Codable {
        let id: String
        let type: String
        let deletedAt: Int
    }

    public struct ExchangeTag: Codable {
        public let id: String
        public let name: String
        public let color: String?
        public let position: Int
        public let updatedAt: Int
    }

    public struct ExchangeURI: Codable {
        let text: String
        let matcher: Int
    }
}

public enum ExchangeSchemaV1 {

    public struct ExchangeVault: Codable {
        public typealias ExchangeVaultOrigin = ExchangeCommon.ExchangeVaultOrigin
        public typealias ExchangeEncryption = ExchangeCommon.ExchangeEncryption
        
        public struct ExchangeVaultItem: Codable {
            struct ExchangeLogin: Codable {
                typealias ExchangeURI = ExchangeCommon.ExchangeURI
                
                let id: String
                let name: String?
                let username: String?
                let password: String?
                let notes: String?
                let securityType: Int?
                let iconType: Int?
                let iconUriIndex: Int?
                let labelText: String?
                let labelColor: String?
                let customImageUrl: String?
                let createdAt: Int
                let updatedAt: Int
                let uris: [ExchangeURI]?
                let tags: [String]?
            }

            typealias ExchangeDeletedItem = ExchangeCommon.ExchangeDeletedItem
            typealias ExchangeTag = ExchangeCommon.ExchangeTag

            public let id: String
            public let createdAt: Int?
            public let updatedAt: Int
            let name: String
            var logins: [ExchangeLogin]?
            var loginsEncrypted: [String]?
            var itemsDeleted: [ExchangeDeletedItem]?
            var itemsDeletedEncrypted: [String]?
            var tags: [ExchangeTag]?
            var tagsEncrypted: [String]?
            
            private enum CodingKeys: String, CodingKey {
                case id
                case name
                case createdAt
                case updatedAt
                case logins
                case loginsEncrypted
                case tags
                case tagsEncrypted
                case itemsDeleted
                case itemsDeletedEncrypted
            }
            
            init(
                id: String,
                name: String,
                createdAt: Int?,
                updatedAt: Int,
                logins: [ExchangeLogin]?,
                loginsEncrypted: [String]?,
                tags: [ExchangeTag]?,
                tagsEncrypted: [String]?,
                itemsDeleted: [ExchangeDeletedItem]?,
                itemsDeletedEncrypted: [String]?
            ) {
                self.id = id
                self.name = name
                self.createdAt = createdAt
                self.updatedAt = updatedAt
                self.logins = logins
                self.loginsEncrypted = loginsEncrypted
                self.tags = tags
                self.tagsEncrypted = tagsEncrypted
                self.itemsDeleted = itemsDeleted
                self.itemsDeletedEncrypted = itemsDeletedEncrypted
            }
            
            public init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                
                id = try container.decode(String.self, forKey: .id)
                name = try container.decode(String.self, forKey: .name)
                createdAt = try container.decode(Int.self, forKey: .createdAt)
                updatedAt = try container.decode(Int.self, forKey: .updatedAt)
                
                logins = try container.decodeIfPresent([ExchangeLogin].self, forKey: .logins)
                loginsEncrypted = try container.decodeIfPresent([String].self, forKey: .loginsEncrypted)
                itemsDeleted = try container.decodeIfPresent([ExchangeDeletedItem].self, forKey: .itemsDeleted)
                itemsDeletedEncrypted = try container.decodeIfPresent([String].self, forKey: .itemsDeletedEncrypted)
                tags = try container.decodeIfPresent([ExchangeTag].self, forKey: .tags)
                tagsEncrypted = try container.decodeIfPresent([String].self, forKey: .tagsEncrypted)
            }
        }
        
        let schemaVersion: Int
        let origin: ExchangeVaultOrigin
        
        public let encryption: ExchangeEncryption?
        public let vault: ExchangeVaultItem
        
        private enum CodingKeys: String, CodingKey {
            case schemaVersion
            case origin
            case encryption
            case vault
        }
        
        public init(schemaVersion: Int, origin: ExchangeVaultOrigin, encryption: ExchangeEncryption?, vault: ExchangeVaultItem) {
            self.schemaVersion = schemaVersion
            self.origin = origin
            self.encryption = encryption
            self.vault = vault
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)            
            origin = try container.decode(ExchangeVaultOrigin.self, forKey: .origin)
            encryption = try container.decodeIfPresent(ExchangeEncryption.self, forKey: .encryption)
            vault = try container.decode(ExchangeVaultItem.self, forKey: .vault)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(schemaVersion, forKey: .schemaVersion)
            try container.encode(origin, forKey: .origin)
            try container.encodeIfPresent(encryption, forKey: .encryption)
            try container.encode(vault, forKey: .vault)
        }
    }
}

public enum ExchangeSchemaV2 {

    public struct ExchangeVault: Codable {
        public typealias ExchangeVaultOrigin = ExchangeCommon.ExchangeVaultOrigin
        public typealias ExchangeEncryption = ExchangeCommon.ExchangeEncryption
        
        public struct ExchangeVaultItem: Codable {
            struct ExchangeItem: Codable {
                typealias ExchangeURI = ExchangeCommon.ExchangeURI

                struct ExchangeLoginContent: Codable {
                    private enum CodingKeys: String, CodingKey {
                        case name
                        case username
                        case password = "s_password"
                        case notes
                        case iconType
                        case iconUriIndex
                        case labelText
                        case labelColor
                        case customImageUrl
                        case uris
                    }
                    
                    let name: String?
                    let username: String?
                    let password: String?
                    let notes: String?
                    let iconType: Int?
                    let iconUriIndex: Int?
                    let labelText: String?
                    let labelColor: String?
                    let customImageUrl: String?
                    let uris: [ExchangeURI]?
                }
                
                let id: String
                let contentType: String
                let contentVersion: Int
                let content: [String: Any]
                let securityType: Int?
                let createdAt: Int
                let updatedAt: Int
                let tags: [String]?
                
                private enum CodingKeys: String, CodingKey {
                    case id
                    case contentType
                    case contentVersion
                    case content
                    case securityType
                    case createdAt
                    case updatedAt
                    case tags
                }
                
                // MARK: - Memberwise initializer
                init(
                    id: String,
                    contentType: String,
                    contentVersion: Int,
                    content: [String: Any],
                    securityType: Int?,
                    createdAt: Int,
                    updatedAt: Int,
                    tags: [String]?
                ) {
                    self.id = id
                    self.contentType = contentType
                    self.contentVersion = contentVersion
                    self.content = content
                    self.securityType = securityType
                    self.createdAt = createdAt
                    self.updatedAt = updatedAt
                    self.tags = tags
                }
                
                // MARK: - Decodable
                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    
                    id = try container.decode(String.self, forKey: .id)
                    contentType = try container.decode(String.self, forKey: .contentType)
                    contentVersion = try container.decode(Int.self, forKey: .contentVersion)
                    
                    // Decode content directly as dictionary using AnyCodable
                    if let contentValue = try? container.decode(AnyCodable.self, forKey: .content),
                       let dict = contentValue.value as? [String: Any] {
                        content = dict
                    } else {
                        content = [:]
                    }
                    
                    securityType = try container.decodeIfPresent(Int.self, forKey: .securityType)
                    createdAt = try container.decode(Int.self, forKey: .createdAt)
                    updatedAt = try container.decode(Int.self, forKey: .updatedAt)
                    tags = try container.decodeIfPresent([String].self, forKey: .tags)
                }
                
                // MARK: - Encodable
                func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)
                    
                    try container.encode(id, forKey: .id)
                    try container.encode(contentType, forKey: .contentType)
                    try container.encode(contentVersion, forKey: .contentVersion)
                    
                    // Encode content dictionary directly as JSON object
                    try container.encode(AnyCodable(content), forKey: .content)
                    
                    try container.encodeIfPresent(securityType, forKey: .securityType)
                    try container.encode(createdAt, forKey: .createdAt)
                    try container.encode(updatedAt, forKey: .updatedAt)
                    try container.encodeIfPresent(tags, forKey: .tags)
                }
            }

            typealias ExchangeDeletedItem = ExchangeCommon.ExchangeDeletedItem
            typealias ExchangeTag = ExchangeCommon.ExchangeTag

            public let id: String
            public let createdAt: Int?
            public let updatedAt: Int
            let name: String
            var items: [ExchangeItem]?
            var itemsEncrypted: [String]?
            var itemsDeleted: [ExchangeDeletedItem]?
            var itemsDeletedEncrypted: [String]?
            var tags: [ExchangeTag]?
            var tagsEncrypted: [String]?
            
            init(
                id: String,
                name: String,
                createdAt: Int?,
                updatedAt: Int,
                items: [ExchangeItem]?,
                itemsEncrypted: [String]?,
                tags: [ExchangeTag]?,
                tagsEncrypted: [String]?,
                itemsDeleted: [ExchangeDeletedItem]?,
                itemsDeletedEncrypted: [String]?
            ) {
                self.id = id
                self.name = name
                self.createdAt = createdAt
                self.updatedAt = updatedAt
                self.items = items
                self.itemsEncrypted = itemsEncrypted
                self.tags = tags
                self.tagsEncrypted = tagsEncrypted
                self.itemsDeleted = itemsDeleted
                self.itemsDeletedEncrypted = itemsDeletedEncrypted
            }
        }
        
        let schemaVersion: Int
        let origin: ExchangeVaultOrigin

        public let encryption: ExchangeEncryption?
        public var vault: ExchangeVaultItem
        
        private enum CodingKeys: String, CodingKey {
            case schemaVersion
            case origin
            case encryption
            case vault
        }
        
        public init(
            schemaVersion: Int,
            origin: ExchangeVaultOrigin,
            encryption: ExchangeEncryption?,
            vault: ExchangeVaultItem
        ) {
            self.schemaVersion = schemaVersion
            self.origin = origin
            self.encryption = encryption
            self.vault = vault
        }
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            
            schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
            
            guard schemaVersion == 2 else {
                throw ExchangeError.mismatchSchemaVersion(schemaVersion, expected: 2)
            }
            
            origin = try container.decode(ExchangeVaultOrigin.self, forKey: .origin)
            encryption = try container.decodeIfPresent(ExchangeEncryption.self, forKey: .encryption)
            
            vault = try container.decode(ExchangeVaultItem.self, forKey: .vault)
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            try container.encode(schemaVersion, forKey: .schemaVersion)
            try container.encode(origin, forKey: .origin)
            try container.encodeIfPresent(encryption, forKey: .encryption)
            try container.encode(vault, forKey: .vault)
        }
    }
}

extension ExchangeSchemaV1.ExchangeVault {
    var hasServices: Bool {
        return vault.logins?.isEmpty == false || vault.loginsEncrypted?.isEmpty == false
    }

    var itemsCount: Int {
        if let lCount = vault.logins?.count {
            return lCount
        } else if let lEncrypted = vault.loginsEncrypted?.count {
            return lEncrypted
        }
        return 0
    }
}

extension ExchangeSchemaV2.ExchangeVault {
    
    static let contentNameKey = "name"
    
    var hasServices: Bool {
        return vault.items?.isEmpty == false || vault.itemsEncrypted?.isEmpty == false
    }
    
    var itemsCount: Int {
        if let lCount = vault.items?.count {
            return lCount
        } else if let lEncrypted = vault.itemsEncrypted?.count {
            return lEncrypted
        }
        return 0
    }
}

extension ExchangeVault.ExchangeVaultItem.ExchangeDeletedItem {
    
    enum DeletedItemType: String {
        case login
        case tag
    }
}
