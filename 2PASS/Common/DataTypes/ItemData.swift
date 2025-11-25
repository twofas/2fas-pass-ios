// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public protocol ItemDataType: Hashable {
    var id: ItemID { get }
    var vaultId: VaultID { get }
    var metadata: ItemMetadata { get }
    var name: String? { get }
    var contentType: ItemContentType { get }
    var contentVersion: Int { get }
    
    func isSecureField(key: String) -> Bool
    func encodeContent(using encoder: JSONEncoder) throws -> Data
}

public struct ItemMetadata: Hashable {
    public let creationDate: Date
    public let modificationDate: Date
    public let protectionLevel: ItemProtectionLevel
    public let trashedStatus: ItemTrashedStatus
    public let tagIds: [ItemTagID]?
    
    public init(
        creationDate: Date,
        modificationDate: Date,
        protectionLevel: ItemProtectionLevel,
        trashedStatus: ItemTrashedStatus,
        tagIds: [ItemTagID]?
    ) {
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.protectionLevel = protectionLevel
        self.trashedStatus = trashedStatus
        self.tagIds = tagIds
    }
}

public enum ItemContentType: Hashable {
    case login
    case secureNote
    case card
    case unknown(String)

    public static let allKnownTypes: [ItemContentType] = [.login, .secureNote, .card]

    public var rawValue: String {
        switch self {
        case .login: "login"
        case .secureNote: "secureNote"
        case .card: "card"
        case .unknown(let contentType): contentType
        }
    }

    public init(rawValue: String) {
        switch rawValue {
        case ItemContentType.login.rawValue: self = .login
        case ItemContentType.secureNote.rawValue: self = .secureNote
        case ItemContentType.card.rawValue: self = .card
        default: self = .unknown(rawValue)
        }
    }

    public func isSecureField(key: String) -> Bool {
        switch self {
        case .login: key == "password"
        default: key.hasPrefix("s_")
        }
    }
}

extension Array where Element == ItemContentType {
    
    public static var allKnownTypes: [ItemContentType] {
        ItemContentType.allKnownTypes
    }
}

public protocol ItemContent: Hashable, Codable {
    static var contentVersion: Int { get }
    static var contentType: ItemContentType { get }
}

extension ItemDataType {
    
    public func isSecureField(key: String) -> Bool {
        contentType.isSecureField(key: key)
    }
}

public enum ItemData: ItemDataType {
    case login(LoginItemData)
    case secureNote(SecureNoteItemData)
    case card(CardItemData)
    case raw(RawItemData)

    public var id: ItemID { base.id }
    public var vaultId: VaultID { base.vaultId }
    public var metadata: ItemMetadata { base.metadata }
    public var name: String? { base.name }
    public var contentType: ItemContentType { base.contentType }
    public var contentVersion: Int { base.contentVersion }

    public func encodeContent(using encoder: JSONEncoder) throws -> Data {
        try base.encodeContent(using: encoder)
    }

    private var base: any ItemDataType {
        switch self {
        case .login(let data): return data
        case .secureNote(let data): return data
        case .card(let data): return data
        case .raw(let data): return data
        }
    }

    public init?(_ rawData: RawItemData, decoder: JSONDecoder = .init()) {
        do {
            switch rawData.contentType {
            case .login:
                self = .login(.init(
                    id: rawData.id,
                    vaultId: rawData.vaultId,
                    metadata: rawData.metadata,
                    name: rawData.name,
                    contentType: rawData.contentType,
                    contentVersion: rawData.contentVersion,
                    content: try decoder.decode(LoginItemData.Content.self, from: rawData.content)
                ))
            case .secureNote:
                self = .secureNote(.init(
                    id: rawData.id,
                    vaultId: rawData.vaultId,
                    metadata: rawData.metadata,
                    name: rawData.name,
                    contentType: rawData.contentType,
                    contentVersion: rawData.contentVersion,
                    content: try decoder.decode(SecureNoteItemData.Content.self, from: rawData.content)
                ))
            case .card:
                self = .card(.init(
                    id: rawData.id,
                    vaultId: rawData.vaultId,
                    metadata: rawData.metadata,
                    name: rawData.name,
                    contentType: rawData.contentType,
                    contentVersion: rawData.contentVersion,
                    content: try decoder.decode(CardItemData.Content.self, from: rawData.content)
                ))
            case .unknown:
                self = .raw(rawData)
            }
        } catch {
            return nil
        }
    }
}

public struct _ItemData<Content>: ItemDataType where Content: Hashable, Content: Codable {
    public typealias Content = Content
    
    public let id: ItemID
    public let vaultId: VaultID
    public let metadata: ItemMetadata
    public let name: String?
    public let contentType: ItemContentType
    public let contentVersion: Int
    public let content: Content
    
    public func encodeContent(using encoder: JSONEncoder) throws -> Data {
        if let contentData = content as? Data {
            return contentData
        } else {
            return try encoder.encode(content)
        }
    }
}

extension _ItemData where Content: ItemContent {
    
    public init(id: ItemID, vaultId: VaultID, metadata: ItemMetadata, name: String?, content: Content) {
        self.id = id
        self.vaultId = vaultId
        self.metadata = metadata
        self.name = name
        self.contentType = Content.contentType
        self.contentVersion = Content.contentVersion
        self.content = content
    }
}

public extension ItemDataType {
    
    var creationDate: Date {
        metadata.creationDate
    }
    
    var modificationDate: Date {
        metadata.modificationDate
    }
    
    var protectionLevel: ItemProtectionLevel {
        metadata.protectionLevel
    }
    
    var trashedStatus: ItemTrashedStatus {
        metadata.trashedStatus
    }
    
    var tagIds: [ItemTagID]? {
        metadata.tagIds
    }
    
    var isTrashed: Bool {
        switch trashedStatus {
        case .no: false
        case .yes: true
        }
    }
}

extension _ItemData {

    public func update(creationDate: Date? = nil, modificationDate: Date? = nil) -> Self {
        _ItemData(
            id: id,
            vaultId: vaultId,
            metadata: ItemMetadata(
                creationDate: creationDate ?? metadata.creationDate,
                modificationDate: modificationDate ?? metadata.modificationDate,
                protectionLevel: metadata.protectionLevel,
                trashedStatus: metadata.trashedStatus,
                tagIds: metadata.tagIds
            ),
            name: name,
            contentType: contentType,
            contentVersion: contentVersion,
            content: content
        )
    }
}

extension ItemData {

    public func update(creationDate: Date? = nil, modificationDate: Date? = nil) -> Self {
        switch self {
        case .login(let data):
            return .login(data.update(creationDate: creationDate, modificationDate: modificationDate))
        case .secureNote(let data):
            return .secureNote(data.update(creationDate: creationDate, modificationDate: modificationDate))
        case .card(let data):
            return .card(data.update(creationDate: creationDate, modificationDate: modificationDate))
        case .raw(let data):
            return .raw(data.update(creationDate: creationDate, modificationDate: modificationDate))
        }
    }
}

