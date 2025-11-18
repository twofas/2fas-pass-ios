// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

typealias ConnectURI = ConnectSchemaV2.ConnectURI
typealias ConnectTag = ConnectSchemaV2.ConnectTag

enum ConnectSchemaV2 {
    
    static let version: ConnectSchemaVersion = .v2
    
    typealias ConnectURI = ConnectSchemaV1.ConnectURI
    typealias ConnectTag = ConnectSchemaV1.ConnectTag
    
    enum DeviceType: String, Codable {
        case mobile
        case tablet
    }
    
    struct ConnectVault: Codable {
        let id: String
        let name: String
        let items: [ConnectItem]
        let tags: [ConnectTag]
    }
    
    struct ConnectItem: Codable {

        struct ConnectLoginContent: Codable {
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
            let uris: [ConnectURI]?
        }
        
        let id: String
        let vaultId: String?
        let contentType: String
        let contentVersion: Int
        let content: [String: Any]
        let securityType: Int?
        let createdAt: Int
        let updatedAt: Int
        let tags: [String]?
        
        private enum CodingKeys: String, CodingKey {
            case id
            case vaultId
            case contentType
            case contentVersion
            case content
            case securityType
            case createdAt
            case updatedAt
            case tags
            case deviceId
        }
        
        // MARK: - Memberwise initializer
        init(
            id: String,
            vaultId: String? = nil,
            contentType: String,
            contentVersion: Int,
            content: [String: Any],
            securityType: Int?,
            createdAt: Int,
            updatedAt: Int,
            tags: [String]?
        ) {
            self.id = id
            self.vaultId = vaultId
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
            vaultId = try container.decodeIfPresent(String.self, forKey: .vaultId)
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
            try container.encode(vaultId, forKey: .vaultId)
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
}
