// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public struct WebDAVLock: Codable {
    public let deviceId: UUID
    public let timestamp: Int
    
    init(deviceId: UUID, timestamp: Int) {
        self.deviceId = deviceId
        self.timestamp = timestamp
    }
}
