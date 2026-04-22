// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public final class BackupS3Controller: @unchecked Sendable {
    public private(set) var session: BackupS3ServiceSession?

    public init() {}

    public func setConfig(_ config: S3ServiceConfig) {
        session = BackupS3ServiceSession(config: config)
    }

    public func clearConfig() {
        session = nil
    }
}
