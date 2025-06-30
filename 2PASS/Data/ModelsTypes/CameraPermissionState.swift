// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

public enum CameraPermissionState {
    case unknown
    case granted
    case denied
    case error
}

extension CameraPermissions.PermissionState {
    var toCameraPermissionState: CameraPermissionState {
        switch self {
        case .unknown: return .unknown
        case .granted: return .granted
        case .denied: return .denied
        case .error: return .error
        }
    }
}

