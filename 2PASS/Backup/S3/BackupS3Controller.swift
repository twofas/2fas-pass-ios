// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import os

public final class BackupS3Controller: Sendable {
    private let lockedSession = OSAllocatedUnfairLock<BackupS3ServiceSession?>(initialState: nil)

    public var session: BackupS3ServiceSession? {
        lockedSession.withLock { $0 }
    }

    public init() {}

    public func setConfig(_ config: S3ServiceConfig) {
        let newSession = BackupS3ServiceSession(config: config)
        lockedSession.withLock { $0 = newSession }
    }

    public func clearConfig() {
        lockedSession.withLock { $0 = nil }
    }
}
