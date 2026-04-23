// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public typealias ExchangeVault = ExchangeSchemaV2.ExchangeVault

public enum ExchangeError: Error {
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
        public let os: String
        public let appVersionCode: Int
        public let appVersionName: String
        public let deviceName: String
        public let deviceId: UUID?

        public init(os: String, appVersionCode: Int, appVersionName: String, deviceName: String, deviceId: UUID?) {
            self.os = os
            self.appVersionCode = appVersionCode
            self.appVersionName = appVersionName
            self.deviceName = deviceName
            self.deviceId = deviceId
        }
    }

    public struct ExchangeEncryption: Codable {
        public struct ExchangeKDFSpec: Codable {
            public let type: String?
            public let hashLength: Int?
            public let memoryMb: Int?
            public let iterations: Int?
            public let parallelism: Int?

            public init(type: String?, hashLength: Int?, memoryMb: Int?, iterations: Int?, parallelism: Int?) {
                self.type = type
                self.hashLength = hashLength
                self.memoryMb = memoryMb
                self.iterations = iterations
                self.parallelism = parallelism
            }
        }

        public let seedHash: String
        public let reference: String
        public let kdfSpec: ExchangeKDFSpec

        public init(seedHash: String, reference: String, kdfSpec: ExchangeKDFSpec) {
            self.seedHash = seedHash
            self.reference = reference
            self.kdfSpec = kdfSpec
        }
    }

    public struct ExchangeDeletedItem: Codable {
        public let id: String
        public let type: String
        public let deletedAt: Int

        public init(id: String, type: String, deletedAt: Int) {
            self.id = id
            self.type = type
            self.deletedAt = deletedAt
        }
    }

    public struct ExchangeTag: Codable {
        public let id: String
        public let name: String
        public let color: String?
        public let position: Int
        public let updatedAt: Int

        public init(id: String, name: String, color: String?, position: Int, updatedAt: Int) {
            self.id = id
            self.name = name
            self.color = color
            self.position = position
            self.updatedAt = updatedAt
        }
    }

    public struct ExchangeURI: Codable {
        public let text: String
        public let matcher: Int

        public init(text: String, matcher: Int) {
            self.text = text
            self.matcher = matcher
        }
    }
}

public enum ExchangeSchemaV1 {

    public struct ExchangeVault: Codable {
        public typealias ExchangeVaultOrigin = ExchangeCommon.ExchangeVaultOrigin
        public typealias ExchangeEncryption = ExchangeCommon.ExchangeEncryption

        public struct ExchangeVaultItem: Codable {
            public struct ExchangeLogin: Codable {
                public typealias ExchangeURI = ExchangeCommon.ExchangeURI

                public let id: String
                public let name: String?
                public let username: String?
                public let password: String?
                public let notes: String?
                public let securityType: Int?
                public let iconType: Int?
                public let iconUriIndex: Int?
                public let labelText: String?
                public let labelColor: String?
                public let customImageUrl: String?
                public let createdAt: Int
                public let updatedAt: Int
                public let uris: [ExchangeURI]?
                public let tags: [String]?

                public init(
                    id: String,
                    name: String?,
                    username: String?,
                    password: String?,
                    notes: String?,
                    securityType: Int?,
                    iconType: Int?,
                    iconUriIndex: Int?,
                    labelText: String?,
                    labelColor: String?,
                    customImageUrl: String?,
                    createdAt: Int,
                    updatedAt: Int,
                    uris: [ExchangeURI]?,
                    tags: [String]?
                ) {
                    self.id = id
                    self.name = name
                    self.username = username
                    self.password = password
                    self.notes = notes
                    self.securityType = securityType
                    self.iconType = iconType
                    self.iconUriIndex = iconUriIndex
                    self.labelText = labelText
                    self.labelColor = labelColor
                    self.customImageUrl = customImageUrl
                    self.createdAt = createdAt
                    self.updatedAt = updatedAt
                    self.uris = uris
                    self.tags = tags
                }
            }

            public typealias ExchangeDeletedItem = ExchangeCommon.ExchangeDeletedItem
            public typealias ExchangeTag = ExchangeCommon.ExchangeTag

            public let id: String
            public let createdAt: Int?
            public let updatedAt: Int
            public let name: String
            public var logins: [ExchangeLogin]?
            public var loginsEncrypted: [String]?
            public var itemsDeleted: [ExchangeDeletedItem]?
            public var itemsDeletedEncrypted: [String]?
            public var tags: [ExchangeTag]?
            public var tagsEncrypted: [String]?

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

            public init(
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

        public let schemaVersion: Int
        public let origin: ExchangeVaultOrigin

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
            public struct ExchangeItem: Codable {
                public typealias ExchangeURI = ExchangeCommon.ExchangeURI

                public struct ExchangeLoginContent: Codable {
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

                    public let name: String?
                    public let username: String?
                    public let password: String?
                    public let notes: String?
                    public let iconType: Int?
                    public let iconUriIndex: Int?
                    public let labelText: String?
                    public let labelColor: String?
                    public let customImageUrl: String?
                    public let uris: [ExchangeURI]?

                    public init(
                        name: String?,
                        username: String?,
                        password: String?,
                        notes: String?,
                        iconType: Int?,
                        iconUriIndex: Int?,
                        labelText: String?,
                        labelColor: String?,
                        customImageUrl: String?,
                        uris: [ExchangeURI]?
                    ) {
                        self.name = name
                        self.username = username
                        self.password = password
                        self.notes = notes
                        self.iconType = iconType
                        self.iconUriIndex = iconUriIndex
                        self.labelText = labelText
                        self.labelColor = labelColor
                        self.customImageUrl = customImageUrl
                        self.uris = uris
                    }
                }

                public let id: String
                public let contentType: String
                public let contentVersion: Int
                public let content: [String: Any]
                public let securityType: Int?
                public let createdAt: Int
                public let updatedAt: Int
                public let tags: [String]?

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

                public init(
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

                public init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    id = try container.decode(String.self, forKey: .id)
                    contentType = try container.decode(String.self, forKey: .contentType)
                    contentVersion = try container.decode(Int.self, forKey: .contentVersion)

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

                public func encode(to encoder: Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encode(id, forKey: .id)
                    try container.encode(contentType, forKey: .contentType)
                    try container.encode(contentVersion, forKey: .contentVersion)

                    try container.encode(AnyCodable(content), forKey: .content)

                    try container.encodeIfPresent(securityType, forKey: .securityType)
                    try container.encode(createdAt, forKey: .createdAt)
                    try container.encode(updatedAt, forKey: .updatedAt)
                    try container.encodeIfPresent(tags, forKey: .tags)
                }
            }

            public typealias ExchangeDeletedItem = ExchangeCommon.ExchangeDeletedItem
            public typealias ExchangeTag = ExchangeCommon.ExchangeTag

            public let id: String
            public let createdAt: Int?
            public let updatedAt: Int
            public let name: String
            public var items: [ExchangeItem]?
            public var itemsEncrypted: [String]?
            public var itemsDeleted: [ExchangeDeletedItem]?
            public var itemsDeletedEncrypted: [String]?
            public var tags: [ExchangeTag]?
            public var tagsEncrypted: [String]?

            public init(
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

        public let schemaVersion: Int
        public let origin: ExchangeVaultOrigin

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

public extension ExchangeSchemaV1.ExchangeVault {
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

public extension ExchangeSchemaV2.ExchangeVault {

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

public extension ExchangeVault.ExchangeVaultItem.ExchangeDeletedItem {

    enum DeletedItemType: String {
        case login
        case tag
    }
}

public enum ExchangeDecodeError: Error, Sendable {
    case schemaNotSupported(version: Int)
}

extension ExchangeVaultVersioned: Decodable {
    /// Peeks the `schemaVersion` first, then decodes into the matching case.
    /// Unknown versions throw `ExchangeDecodeError.schemaNotSupported`;
    /// malformed JSON or per-schema decoding failures propagate as `DecodingError`.
    public init(from decoder: Decoder) throws {
        struct SchemaPeek: Decodable {
            let schemaVersion: Int
        }
        let peek = try SchemaPeek(from: decoder)

        switch peek.schemaVersion {
        case 1:
            self = .v1(try ExchangeSchemaV1.ExchangeVault(from: decoder))
        case 2:
            self = .v2(try ExchangeSchemaV2.ExchangeVault(from: decoder))
        default:
            throw ExchangeDecodeError.schemaNotSupported(version: peek.schemaVersion)
        }
    }
}
