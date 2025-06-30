// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

struct ConnectLogin: Codable {
    struct ConnectURI: Codable {
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
    let uris: [ConnectURI]?
    let deviceId: UUID
}
