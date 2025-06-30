// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public struct PasswordEncryptedURIs: Hashable, Codable {
    public let uris: Data
    public let match: [PasswordURI.Match]
    
    public init(uris: Data, match: [PasswordURI.Match]) {
        self.uris = uris
        self.match = match
    }
}
