// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common
import CommonUI

enum ConnectCameraDestination: Identifiable {
    case connecting(ConnectSession, onScanAgain: Callback)
    
    var id: String {
        switch self {
        case .connecting(let session, _):
            "connecting_\(session.sessionId)"
        }
    }
}

@Observable
final class ConnectCameraPresenter {
    var destination: ConnectCameraDestination?
    var showInvalidCodeError = false

    private let onScanAgain: Callback
    private let _onScannedQRCode: Callback
    private let scanDebouncer = ScanDebouncer()

    init(onScannedQRCode: @escaping Callback, onScanAgain: @escaping Callback) {
        self._onScannedQRCode = onScannedQRCode
        self.onScanAgain = onScanAgain
    }

    @MainActor
    func onAppear() {
        scanDebouncer.reset()
        showInvalidCodeError = false
    }

    @MainActor
    func onScannedQRCode(_ code: String) {
        scanDebouncer.scheduleDetected(code: code) { [weak self] code in
            guard let self else { return }

            guard let session = ConnectSession(qrCode: code) else {
                self.showInvalidCodeError = true
                return
            }
            
            guard session.verify() else {
                return
            }

            self.showInvalidCodeError = false
            self.destination = .connecting(session, onScanAgain: self.onScanAgain)
            self._onScannedQRCode()
        }
    }

    @MainActor
    func onCodeLost() {
        scanDebouncer.scheduleLost { [weak self] in
            self?.showInvalidCodeError = false
        }
    }
}
