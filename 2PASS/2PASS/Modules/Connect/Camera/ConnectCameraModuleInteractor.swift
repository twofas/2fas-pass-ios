// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import Data

protocol ConnectCameraModuleInteracting: AnyObject {
#if DEBUG
    @MainActor var e2eScannedCodes: Notifications.MessageSequence<E2EConnectCodeScanned> { get }
#endif
}

final class ConnectCameraModuleInteractor: ConnectCameraModuleInteracting {

#if DEBUG
    private let debugCameraInteractor: ConnectDebugCameraInteracting

    init(debugCameraInteractor: ConnectDebugCameraInteracting) {
        self.debugCameraInteractor = debugCameraInteractor
    }
#else
    init() {}
#endif

#if DEBUG
    @MainActor
    var e2eScannedCodes: Notifications.MessageSequence<E2EConnectCodeScanned> {
        debugCameraInteractor.scannedCodes
    }
#endif
}
