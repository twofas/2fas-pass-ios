// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import Data

enum ForgotMasterPasswordRecoveryError: Error {
    case verificationError
    case validationError
    case missingMasterKey
    case appLocked
}

@Observable
final class ForgotMasterPasswordRecoveryPresenter {
    private(set) var result: Result<Void, ForgotMasterPasswordRecoveryError>?

    private let interactor: ForgotMasterPasswordRecoveryModuleInteracting
    private let entropy: Entropy
    private let masterKey: MasterKey?
    private let onSuccess: Callback
    private let onTryAgain: Callback
    private let onClose: Callback

    private var hasStarted = false

    @ObservationIgnored
    private var logoutObservationTask: Task<Void, Never>?

    init(
        interactor: ForgotMasterPasswordRecoveryModuleInteracting,
        entropy: Entropy,
        masterKey: MasterKey?,
        onSuccess: @escaping Callback,
        onTryAgain: @escaping Callback,
        onClose: @escaping Callback
    ) {
        self.interactor = interactor
        self.entropy = entropy
        self.masterKey = masterKey
        self.onSuccess = onSuccess
        self.onTryAgain = onTryAgain
        self.onClose = onClose
    }

    func handleSuccess() {
        onSuccess()
    }

    func handleTryAgain() {
        onTryAgain()
    }

    func handleClose() {
        onClose()
    }

    func onAppear() {
        observeLogout()
        guard !hasStarted else { return }
        hasStarted = true
        recover()
    }

    func onDisappear() {
        logoutObservationTask?.cancel()
        logoutObservationTask = nil
    }

    deinit {
        logoutObservationTask?.cancel()
    }
}

private extension ForgotMasterPasswordRecoveryPresenter {
    func observeLogout() {
        guard logoutObservationTask == nil else { return }
        logoutObservationTask = Task { @MainActor [weak self, interactor] in
            for await _ in interactor.didLogoutApp {
                guard let self, case .success = self.result else { continue }
                self.onClose()
            }
        }
    }

    func recover() {
        guard interactor.isAppLocked == false else {
            result = .failure(.appLocked)
            return
        }
        
        guard let masterKey = masterKey else {
            result = .failure(.missingMasterKey)
            return
        }
        
        Task { @MainActor [weak self] in
            guard let self else { return }

            let success = await self.interactor.loginUsingMasterKey(masterKey, entropy: entropy)
            if success {
                self.result = .success(())
            } else if self.interactor.isAppLocked {
                self.result = .failure(.appLocked)
            } else {
                self.result = .failure(.verificationError)
            }
        }
    }
}
