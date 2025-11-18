// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

enum ConnectDeviceType: String, Codable {
    case mobile
    case tablet
}

extension ConnectDeviceType {
    
    init(_ deviceType: DeviceType) {
        switch deviceType {
        case .phone, .unknown:
            self = .mobile
        case .pad:
            self = .tablet
        }
    }
}
