// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

#if DEBUG
import Foundation

extension MainRepositoryImpl {

    var isE2EConnectCameraForced: Bool {
        ProcessInfo.processInfo.arguments.contains("e2eConnectCamera")
    }
}
#endif
