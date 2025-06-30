// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public struct PasswordDataChangeRequest: Hashable {
    public let name: String?
    public let username: String?
    public let password: Password?
    public let notes: String?
    public let protectionLevel: PasswordProtectionLevel?
    public let uris: [PasswordURI]?
    
    public enum Password: Hashable {
        case value(String)
        case generateNewPassword
        
        public var value: String? {
            switch self {
            case .value(let value):
                return value
            case .generateNewPassword:
                return nil
            }
        }
    }
    
    public init(name: String? = nil, username: String? = nil, password: Password? = nil, notes: String? = nil, protectionLevel: PasswordProtectionLevel? = nil, uris: [PasswordURI]? = nil) {
        self.name = name
        self.username = username
        self.password = password
        self.notes = notes
        self.protectionLevel = protectionLevel
        self.uris = uris
    }
}
