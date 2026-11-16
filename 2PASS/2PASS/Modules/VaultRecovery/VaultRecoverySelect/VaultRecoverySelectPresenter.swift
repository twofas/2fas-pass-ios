// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Data
import Common
import PhotosUI
import SwiftUI

struct VaultRecoveryFlowContext {
    
    enum Kind {
        case onboarding
        case importVault
        case restoreVault
    }
    
    let kind: Kind
    let onClose: Callback
    
    static func onboarding(onClose: @escaping Callback) -> Self {
        .init(kind: .onboarding, onClose: onClose)
    }
    
    static func importVault(onClose: @escaping Callback) -> Self {
        .init(kind: .importVault, onClose: onClose)
    }
    
    static var restoreVault: Self {
        .init(kind: .restoreVault, onClose: {})
    }
    
    private init(kind: Kind, onClose: @escaping Callback) {
        self.kind = kind
        self.onClose = onClose
    }
}

enum VaultRecoverySelectDestination: Identifiable {
    var id: String {
        switch self {
        case .camera: "camera"
        case .manually: "manually"
        case .errorOpeningFile: "errorOpeningFile"
        case .vaultRecovery: "vaultRecovery"
        case .enterMasterPassword: "enterMasterPassword"
        case .importVault: "importing"
        case .importFailed: "importFailed"
        }
    }
    
    case camera(onScanned: (Entropy, MasterKey?) -> Void)
    case manually(recoveryData: VaultRecoveryData, onEntropy: (Entropy) -> Void)
    case errorOpeningFile(message: String, onClose: Callback)
    case vaultRecovery(
        entropy: Entropy,
        masterKey: MasterKey,
        recoveryData: VaultRecoveryData,
        onTryAgain: Callback
    )
    
    case importVault(BackupImportInput, onClose: Callback)
    
    case enterMasterPassword(
        flowContext: VaultRecoveryFlowContext,
        entropy: Entropy,
        recoveryData: VaultRecoveryData,
        onTryAgain: Callback
    )
    
    case importFailed(onSelectVault: Callback, onSelectDecryptionKit: Callback)
}

@Observable
final class VaultRecoverySelectPresenter {
    private let interactor: VaultRecoverySelectModuleInteracting
    private let recoveryData: VaultRecoveryData
    
    let flowContext: VaultRecoveryFlowContext
    
    var showFileImporter = false
    var destination: VaultRecoverySelectDestination?
    
    init(
        flowContext: VaultRecoveryFlowContext,
        interactor: VaultRecoverySelectModuleInteracting,
        recoveryData: VaultRecoveryData
    ) {
        self.flowContext = flowContext
        self.interactor = interactor
        self.recoveryData = recoveryData
    }
}

extension VaultRecoverySelectPresenter {
    func onCamera() {
        destination = .camera(onScanned: { [weak self] entropy, masterKey in
            self?.destination = nil

            Task { @MainActor in
                self?.handleDecryptionKit(entropy: entropy, masterKey: masterKey)
            }
        })
    }
    
    func onFiles() {
        showFileImporter = true
    }
    
    func onEnterManually() {
        destination = .manually(recoveryData: recoveryData, onEntropy: { [weak self] entropy in
            self?.destination = nil
            
            Task { @MainActor in
                guard let self else { return }
                self.destination = .enterMasterPassword(
                    flowContext: self.flowContext,
                    entropy: entropy,
                    recoveryData: self.recoveryData,
                    onTryAgain: { [weak self] in
                        self?.destination = nil
                    }
                )
            }
        })
    }
    
    func onFileOpen(_ url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            self.interactor.openFile(url: url) { [weak self] result in
                switch result {
                case .success(let data):
                    var image: UIImage?
                    if self?.interactor.isPDF(fileURL: url) == true {
                        image = self?.interactor.pdfToImage(url: url)
                    } else if let img = UIImage(data: data) {
                        image = img
                    }
                    
                    guard let image else {
                        DispatchQueue.main.async {
                            self?.destination = .errorOpeningFile(message: String(localized: .vaultRecoveryErrorOpenFile)) { [weak self] in
                                self?.destination = nil
                            }
                        }
                        return
                    }
                    self?.scan(image)
                case .failure(let error):
                    DispatchQueue.main.async {
                        switch error {
                        case .cantReadFile(let reason):
                            let reason = reason ?? ""
                            self?.destination = .errorOpeningFile(message: String(localized: .vaultRecoveryErrorOpenFileDetails(reason))) { [weak self] in
                                self?.destination = nil
                            }
                        }
                    }
                }
            }
        }
    }
    
    func onFileError(_ error: Error) {
        destination = .errorOpeningFile(message: error.localizedDescription) { [weak self] in
            self?.destination = nil
        }
    }
    
    func onFileFromGallery(_ image: UIImage) {
        scan(image)
    }
    
    func onGalleryError() {
        destination = .errorOpeningFile(message: String(localized: .vaultRecoveryErrorGalleryAccess)) { [weak self] in
            self?.destination = nil
        }
    }
}

private extension VaultRecoverySelectPresenter {
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

                DispatchQueue.main.async {
                    self.handleDecryptionKit(entropy: parseResult.entropy, masterKey: parseResult.masterKey)
                }
            case .failure:
                showError()
            }
        }
    }

    func handleDecryptionKit(entropy: Entropy, masterKey: MasterKey?) {
        guard interactor.validateEntropy(entropy, for: recoveryData) else {
            destination = .importFailed(onSelectVault: { [weak self] in
                self?.flowContext.onClose()
            }, onSelectDecryptionKit: { [weak self] in
                self?.destination = nil
            })
            return
        }

        continueRecovery(entropy: entropy, masterKey: masterKey)
    }

    func continueRecovery(entropy: Entropy, masterKey: MasterKey?) {
        guard let masterKey else {
            destination = .enterMasterPassword(
                flowContext: flowContext,
                entropy: entropy,
                recoveryData: recoveryData,
                onTryAgain: { [weak self] in
                    self?.destination = nil
                }
            )
            return
        }

        switch flowContext.kind {
        case .onboarding, .restoreVault:
            destination = .vaultRecovery(
                entropy: entropy,
                masterKey: masterKey,
                recoveryData: recoveryData,
                onTryAgain: { [weak self] in
                    self?.destination = nil
                }
            )
        case .importVault:
            switch recoveryData {
            case .cloud:
                fatalError("Unsupported importing vault from cloud")
            case .localVault:
                fatalError("Unsupported importing local vault")
            case .file(let file, _):
                destination = .importVault(
                    .encrypted(entropy: entropy, masterKey: masterKey, vault: file),
                    onClose: flowContext.onClose
                )
            }
        }
    }
}
