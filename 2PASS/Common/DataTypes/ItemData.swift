// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public protocol ItemDataType: Hashable {
    var id: ItemID { get }
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
    case unknown(String)
    
    public var rawValue: String {
        switch self {
        case .login: "login"
        case .secureNote: "secureNote"
        case .unknown(let contentType): contentType
        }
    }
    
    public init(rawValue: String) {
        switch rawValue {
        case ItemContentType.login.rawValue: self = .login
        case ItemContentType.secureNote.rawValue: self = .secureNote
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
    case raw(RawItemData)
    
    public var id: ItemID { base.id }
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
        case .raw(let data): return data
        }
    }
    
    public init?(_ rawData: RawItemData, decoder: JSONDecoder = .init()) {
        do {
            switch rawData.contentType {
            case .login:
                self = .login(.init(
                    id: rawData.id,
                    metadata: rawData.metadata,
                    name: rawData.name,
                    contentType: rawData.contentType,
                    contentVersion: rawData.contentVersion,
                    content: try decoder.decode(LoginItemData.Content.self, from: rawData.content)
                ))
            case .secureNote:
                self = .secureNote(.init(
                    id: rawData.id,
                    metadata: rawData.metadata,
                    name: rawData.name,
                    contentType: rawData.contentType,
                    contentVersion: rawData.contentVersion,
                    content: try decoder.decode(SecureNoteItemData.Content.self, from: rawData.content)
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
    
    public init(id: ItemID, metadata: ItemMetadata, name: String?, content: Content) {
        self.id = id
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

