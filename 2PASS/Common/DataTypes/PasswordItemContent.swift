// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public struct PasswordItemContent: Codable {
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
