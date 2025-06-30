// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public struct WebBrowser: Identifiable, Codable {
    public let id: UUID
    public let publicKey: String
    public var name: String
    public var version: String
    public var extName: String
    public let firstConnectionDate: Date
    public var lastConnectionDate: Date
    
    var nextSessionID: Data?
}
