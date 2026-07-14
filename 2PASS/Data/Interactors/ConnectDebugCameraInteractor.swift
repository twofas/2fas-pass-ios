// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

#if DEBUG
import Foundation
import Common

/// Debug-only test seam that lets the E2E harness inject a Connect QR payload (the base64
/// `qrData` a real camera scan would yield) without a camera.
public protocol ConnectDebugCameraInteracting: AnyObject {
    
    var isCameraForced: Bool { get }

    @MainActor var scannedCodes: Notifications.MessageSequence<E2EConnectCodeScanned> { get }

    /// Parses a Connect QR payload from a debug deep link and broadcasts it to the live camera screen
    /// (a no-op if none is open). Returns true if `url` was an E2E Connect deep link.
    func notifyScannedCode(fromDeepLink url: URL) -> Bool
}

final class ConnectDebugCameraInteractor: ConnectDebugCameraInteracting {

    private let mainRepository: MainRepository

    init(mainRepository: MainRepository) {
        self.mainRepository = mainRepository
    }

    var isCameraForced: Bool {
        mainRepository.isE2EConnectCameraForced
    }

    @MainActor
    var scannedCodes: Notifications.MessageSequence<E2EConnectCodeScanned> {
        NotificationCenter.default.messages(of: E2EConnectCodeScanned.self)
    }

    func notifyScannedCode(fromDeepLink url: URL) -> Bool {
        guard url.scheme == "twofaspass" || url.scheme == "dev-twofaspass",
              url.host == "e2e-connect",
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              let code = items.first(where: { $0.name == "qr" })?.value,
              !code.isEmpty
        else { return false }

        Task { @MainActor in
            NotificationCenter.default.post(E2EConnectCodeScanned(code: code))
        }
        return true
    }
}
#endif
