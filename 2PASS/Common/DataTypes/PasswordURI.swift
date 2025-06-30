// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public struct PasswordURI: Hashable, Codable {
    public enum Match: String, CaseIterable, Hashable, Codable {
        case domain
        case host
        case startsWith
        case exact
    }
    
    public let uri: String
    public let match: Match
    
    public init(uri: String, match: Match) {
        self.uri = uri
        self.match = match
    }
}

extension PasswordURI.Match {
    
    public init?(intValue: Int) {
        switch intValue {
        case 0:
            self = .domain
        case 1:
            self = .host
        case 2:
            self = .startsWith
        case 3:
            self = .exact
        default:
            return nil
        }
    }
}
