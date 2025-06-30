// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public struct DeviceName: Codable, Hashable {
    public let deviceID: DeviceID
    public let deviceName: String
    
    public init(deviceID: DeviceID, deviceName: String) {
        self.deviceID = deviceID
        self.deviceName = deviceName
    }
}
