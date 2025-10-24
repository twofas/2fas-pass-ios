// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

enum ConnectSchemaV1 {
 
    static let version: ConnectSchemaVersion = .v1
    
    struct ConnectTag: Codable {
        let id: String
        let name: String
        let color: String?
        let position: Int
        let updatedAt: Int
    }
    
    struct ConnectURI: Codable {
        let text: String
        let matcher: Int
    }
    
    struct ConnectVault: Codable {
        let logins: String
        let tags: String
    }
    
    struct ConnectLogin: Codable {
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
        let uris: [ConnectURI]?
        let tags: [String]?
        let deviceId: UUID
    }
}
