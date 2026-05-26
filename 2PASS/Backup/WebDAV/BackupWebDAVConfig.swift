// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public struct BackupWebDAVConfig: Codable, Equatable, Sendable {
    public let baseURL: String
    public let normalizedURL: URL
    public let lockTime: Int
    public let allowTLSOff: Bool
    public let login: String?
    public let password: String?

    public init(
        baseURL: String,
        normalizedURL: URL,
        lockTime: Int,
        allowTLSOff: Bool,
        login: String?,
        password: String?
    ) {
        self.baseURL = baseURL
        self.normalizedURL = normalizedURL
        self.lockTime = lockTime
        self.allowTLSOff = allowTLSOff
        self.login = login
        self.password = password
    }

    public init(baseURL: String, normalizedURL: URL, allowTLSOff: Bool, login: String?, password: String?) {
        self.baseURL = baseURL
        self.normalizedURL = normalizedURL
        self.lockTime = Config.webDAVLockFileTime
        self.allowTLSOff = allowTLSOff
        self.login = login
        self.password = password
    }
}
