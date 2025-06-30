// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

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

    private let onScanAgain: Callback
    private let _onScannedQRCode: Callback
    
    private(set) var lastQrCode: String?
    
    init(onScannedQRCode: @escaping Callback, onScanAgain: @escaping Callback) {
        self._onScannedQRCode = onScannedQRCode
        self.onScanAgain = onScanAgain
    }
    
    func onAppear() {
        lastQrCode = nil
    }
    
    func onScannedQRCode(_ code: String) {
        guard code != lastQrCode else {
            return
        }
        
        lastQrCode = code

        guard let session = ConnectSession(qrCode: code), session.verify() else {
            return
        }
        
        destination = .connecting(session, onScanAgain: onScanAgain)
        _onScannedQRCode()
    }

    func onHelp() {
    }
}
