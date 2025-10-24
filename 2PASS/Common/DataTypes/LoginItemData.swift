// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public typealias LoginItemData = _ItemData<LoginItemContent>

public struct LoginItemContent: ItemContent {

    public static let contentType: ItemContentType = .login
    public static let contentVersion = 1
    
    public let name: String?
    public let username: String?
    public let password: Data?
    public let notes: String?
    public let iconType: PasswordIconType
    public let uris: [PasswordURI]?
    
    public init(name: String?, username: String?, password: Data?, notes: String?, iconType: PasswordIconType, uris: [PasswordURI]?) {
        self.name = name
        self.username = username
        self.password = password
        self.notes = notes
        self.iconType = iconType
        self.uris = uris
    }
}

extension LoginItemData {
    
    public var username: String? {
        content.username
    }
    
    public var password: Data? {
        content.password
    }
    
    public var notes: String? {
        content.notes
    }
    
    public var iconType: PasswordIconType {
        content.iconType
    }
    
    public var uris: [PasswordURI]? {
        content.uris
    }
}

extension ItemData {
    
    public var asLoginItem: LoginItemData? {
        switch self {
        case .login(let loginItem): loginItem
        default: nil
        }
    }
}
