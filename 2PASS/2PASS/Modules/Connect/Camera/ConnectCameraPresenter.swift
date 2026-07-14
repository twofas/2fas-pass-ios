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

    private let interactor: ConnectCameraModuleInteracting

#if DEBUG
    @ObservationIgnored private var e2eObservationTask: Task<Void, Never>?
#endif

    init(interactor: ConnectCameraModuleInteracting, onScannedQRCode: @escaping Callback, onScanAgain: @escaping Callback) {
        self.interactor = interactor
        self._onScannedQRCode = onScannedQRCode
        self.onScanAgain = onScanAgain
    }

#if DEBUG
    deinit {
        e2eObservationTask?.cancel()
    }
#endif

    @MainActor
    func onAppear() {
        scanDebouncer.reset()
        showInvalidCodeError = false
#if DEBUG
        startObservingE2ECodes()
#endif
    }

    @MainActor
    func onDisappear() {
#if DEBUG
        e2eObservationTask?.cancel()
        e2eObservationTask = nil
#endif
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

#if DEBUG
    @MainActor
    private func startObservingE2ECodes() {
        e2eObservationTask?.cancel()
        e2eObservationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await message in self.interactor.e2eScannedCodes {
                self.onScannedQRCode(message.code)
            }
        }
    }
#endif
}
