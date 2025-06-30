// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public struct WebBrowserEncryptedData: Identifiable {
    public let id: UUID
    public let publicKey: Data
    public let name: Data
    public let version: Data
    public let extName: Data
    public let firstConnectionDate: Date
    public let lastConnectionDate: Date
    public let nextSessionID: Data?
    
    public init(id: UUID, publicKey: Data, name: Data, version: Data, extName: Data, firstConnectionDate: Date, lastConnectionDate: Date, nextSessionID: Data?) {
        self.id = id
        self.publicKey = publicKey
        self.name = name
        self.version = version
        self.extName = extName
        self.firstConnectionDate = firstConnectionDate
        self.lastConnectionDate = lastConnectionDate
        self.nextSessionID = nextSessionID
    }
}
