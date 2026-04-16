// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI
import Common
import Data

enum ForgotMasterPasswordDestination: RouterDestination {
    case errorOpeningFile(message: String, onClose: Callback)
    case camera(config: LoginModuleInteractorConfig, onSuccess: Callback, onTryAgain: Callback, onClose: Callback)
    case recovery(
        config: LoginModuleInteractorConfig,
        entropy: Entropy,
        masterKey: MasterKey?,
        onSuccess: Callback,
        onTryAgain: Callback,
        onClose: Callback
    )

    var id: String {
        switch self {
        case .errorOpeningFile:
            return "errorOpeningFile"
        case .camera:
            return "camera"
        case .recovery:
            return "recovery"
        }
    }
}

@Observable
final class ForgotMasterPasswordPresenter {

    var destination: ForgotMasterPasswordDestination?
    var showFileImporter = false

    private let interactor: ForgotMasterPasswordModuleInteracting
    private let onSuccess: Callback
    private let onClose: Callback

    private var config: LoginModuleInteractorConfig {
        interactor.loginConfig
    }

    init(interactor: ForgotMasterPasswordModuleInteracting, onSuccess: @escaping Callback, onClose: @escaping Callback) {
        self.interactor = interactor
        self.onSuccess = onSuccess
        self.onClose = onClose
    }

    func close() {
        onClose()
    }

    func onAppear() {}
    
    func onFiles() {
        showFileImporter = true
    }
    
    func onCamera() {
        destination = .camera(
            config: config,
            onSuccess: onSuccess,
            onTryAgain: { [weak self] in
                self?.destination = nil
            },
            onClose: onClose
        )
    }
    
    func onFileOpen(_ url: URL) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let data = try await interactor.openFile(url: url)
                var image: UIImage?
                if interactor.isPDF(fileURL: url) {
                    image = interactor.pdfToImage(url: url)
                } else if let img = UIImage(data: data) {
                    image = img
                }

                guard let image else {
                    destination = .errorOpeningFile(message: String(localized: .vaultRecoveryErrorOpenFile)) { [weak self] in
                        self?.destination = nil
                    }
                    return
                }
                scan(image)
            } catch let error as ImportOpenFileError {
                switch error {
                case .cantReadFile(let reason):
                    let reason = reason ?? ""
                    destination = .errorOpeningFile(message: String(localized: .vaultRecoveryErrorOpenFileDetails(reason))) { [weak self] in
                        self?.destination = nil
                    }
                }
            } catch {
                destination = .errorOpeningFile(message: error.localizedDescription) { [weak self] in
                    self?.destination = nil
                }
            }
        }
    }
    
    func onFileError(_ error: Error) {
        destination = .errorOpeningFile(message: error.localizedDescription) { [weak self] in
            self?.destination = nil
        }
    }
}

private extension ForgotMasterPasswordPresenter {
    func scan(_ image: UIImage) {
        func showError() {
            DispatchQueue.main.async {
                self.destination = .errorOpeningFile(message: String(localized: .vaultRecoveryErrorScanningFile)) { [weak self] in
                    self?.destination = nil
                }
            }
        }
        interactor.scan(image: image) { [weak self] result in
            switch result {
            case .success(let qrCodeString):
                guard let self, let first = qrCodeString.first else {
                    showError()
                    return
                }
                guard let parseResult = interactor.parseQRCodeContents(first) else {
                    showError()
                    return
                }
                self.handleScanResult(entropy: parseResult.entropy, masterKey: parseResult.masterKey)
            case .failure:
                showError()
            }
        }
    }
}

private extension ForgotMasterPasswordPresenter {
    
    func handleScanResult(entropy: Entropy, masterKey: MasterKey?) {
        destination = .recovery(
            config: config,
            entropy: entropy,
            masterKey: masterKey,
            onSuccess: onSuccess,
            onTryAgain: { [weak self] in
                self?.destination = nil
            },
            onClose: onClose
        )
    }
}
