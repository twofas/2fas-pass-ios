// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

#if DEBUG
import Foundation

/// Debug-only E2E test seam: posted when a Connect QR payload is injected via a debug deep link
public struct E2EConnectCodeScanned: Notifications.MainActorMessage {
    public typealias Subject = NSObject

    public let code: String

    public init(code: String) {
        self.code = code
    }
}
#endif
