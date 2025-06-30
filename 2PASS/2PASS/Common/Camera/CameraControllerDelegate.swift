// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

protocol CameraControllerDelegate: AnyObject {
    func cameraDidInitialize()
    func cameraFailedToInitilize(with error: CameraController.CameraError)
    func cameraStartedPreview()
    func cameraStoppedPreview()
    func cameraFreezedPreview()
    func cameraUnfreezedPreview()
    func cameraDidClear()
}
