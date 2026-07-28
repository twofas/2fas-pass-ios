// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common
import CommonUI

@Observable
final class ConnectCameraPresenter {
    var showInvalidCodeError = false

    /// Bumped on every successfully verified scan; drives the selection haptic in the camera view.
    private(set) var scanFeedbackTrigger = 0

    /// Hands the scanned session to the host, which owns the acceptance-sheet presentation for both
    /// layouts (it dismisses the split's Connect modal or switches off the Connect tab first, then
    /// presents the sheet from a parent that survives).
    private let onScannedSession: (ConnectSession) -> Void

    private let scanDebouncer = ScanDebouncer()

    private let interactor: ConnectCameraModuleInteracting

#if DEBUG
    @ObservationIgnored private var e2eObservationTask: Task<Void, Never>?
#endif

    init(interactor: ConnectCameraModuleInteracting, onScannedSession: @escaping (ConnectSession) -> Void) {
        self.interactor = interactor
        self.onScannedSession = onScannedSession
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
            self.scanFeedbackTrigger += 1
            self.onScannedSession(session)
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
