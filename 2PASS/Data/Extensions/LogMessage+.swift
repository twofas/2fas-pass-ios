// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import AVFoundation

extension LogMessage.Interpolation {
    
    mutating func appendInterpolation(_ value: @autoclosure () -> AVAuthorizationStatus, privacy: LogPrivacy = .auto) {
        appendInterpolation("\(value())", privacy: privacy == .auto ? .public : privacy)
    }
    
    mutating func appendInterpolation(_ value: @autoclosure () -> CameraPermissionState, privacy: LogPrivacy = .auto) {
        appendInterpolation("\(value())", privacy: privacy == .auto ? .public : privacy)
    }
}
