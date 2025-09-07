// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public struct ExchangeVault: Codable {
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
    
    public struct ExchangeVaultItem: Codable {
        struct ExchangeLogin: Codable {
            struct ExchangeURI: Codable {
                let text: String
                let matcher: Int
            }
            
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
        
        struct ExchangeDeletedItem: Codable {
            let id: String
            let type: String
            let deletedAt: Int
        }
        
        struct ExchangeTag: Codable {
            public let id: String
            public let name: String
            public let color: String?
            public let position: Int
            public let updatedAt: Int
        }
        
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
}

extension ExchangeVault {
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

extension ExchangeVault.ExchangeVaultItem.ExchangeDeletedItem {
    
    enum DeletedItemType: String {
        case login
        case tag
    }
}
