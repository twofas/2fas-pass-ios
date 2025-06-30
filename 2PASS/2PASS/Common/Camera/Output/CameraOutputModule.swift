// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import AVFoundation

public protocol CameraOutputModule: AnyObject {
    var output: AVCaptureOutput? { get }

    func registered()
    func clear()
}
