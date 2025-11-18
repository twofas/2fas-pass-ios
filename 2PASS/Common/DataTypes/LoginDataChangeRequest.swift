// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public struct LoginDataChangeRequest: Hashable {
    public let name: String?
    public let username: Field?
    public let password: Field?
    public let notes: String?
    public let protectionLevel: ItemProtectionLevel?
    public let uris: [PasswordURI]?
    public let tags: [ItemTagID]?
    
    public enum Field: Hashable {
        case value(String)
        case generate
        
        public var value: String? {
            switch self {
            case .value(let value):
                return value
            case .generate:
                return nil
            }
        }
    }
    
    public init(name: String? = nil, username: Field? = nil, password: Field? = nil, notes: String? = nil, protectionLevel: ItemProtectionLevel? = nil, uris: [PasswordURI]? = nil, tags: [ItemTagID]? = nil) {
        self.name = name
        self.username = username
        self.password = password
        self.notes = notes
        self.protectionLevel = protectionLevel
        self.uris = uris
        self.tags = tags
    }
}
