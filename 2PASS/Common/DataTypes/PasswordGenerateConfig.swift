// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public struct PasswordGenerateConfig: Codable {
    public let length: Int
    public var hasDigits: Bool
    public var hasUppercase: Bool
    public var hasSpecial: Bool
    
    public init(length: Int, hasDigits: Bool, hasUppercase: Bool, hasSpecial: Bool) {
        self.length = length
        self.hasDigits = hasDigits
        self.hasUppercase = hasUppercase
        self.hasSpecial = hasSpecial
    }
}
