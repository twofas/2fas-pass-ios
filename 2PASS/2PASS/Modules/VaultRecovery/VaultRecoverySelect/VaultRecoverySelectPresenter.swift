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
    }
    
    let kind: Kind
    let onClose: Callback?
    
    static var onboarding: Self {
        .init(kind: .onboarding)
    }
    
    static func importVault(onClose: @escaping Callback) -> Self {
        .init(kind: .importVault, onClose: onClose)
    }
    
    private init(kind: Kind, onClose: Callback? = nil) {
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
        }
    }
    
    case camera(flowContext: VaultRecoveryFlowContext, recoveryData: VaultRecoveryData)
    case manually(recoveryData: VaultRecoveryData, onEntropy: (Entropy) -> Void)
    case errorOpeningFile(message: String, onClose: Callback)
    case vaultRecovery(
        entropy: Entropy,
        masterKey: MasterKey,
        recoveryData: VaultRecoveryData
    )
    
    case importVault(BackupImportInput, onClose: Callback)
    
    case enterMasterPassword(
        flowContext: VaultRecoveryFlowContext,
        entropy: Entropy,
        recoveryData: VaultRecoveryData,
    )
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
        destination = .camera(flowContext: flowContext, recoveryData: recoveryData)
    }
    
    func onFiles() {
        showFileImporter = true
    }
    
    func onEnterManually() {
        destination = .manually(recoveryData: recoveryData, onEntropy: { [weak self] entropy in
            self?.destination = nil
            
            Task { @MainActor in
                try await Task.sleep(for: .milliseconds(700))
                
                guard let self else { return }
                self.destination = .enterMasterPassword(flowContext: self.flowContext, entropy: entropy, recoveryData: self.recoveryData)
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
                            self?.destination = .errorOpeningFile(message: T.vaultRecoveryErrorOpenFile) { [weak self] in
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
                            self?.destination = .errorOpeningFile(message: T.vaultRecoveryErrorOpenFileDetails(reason)) { [weak self] in
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
        destination = .errorOpeningFile(message: T.vaultRecoveryErrorGalleryAccess) { [weak self] in
            self?.destination = nil
        }
    }
}

private extension VaultRecoverySelectPresenter {
    func scan(_ image: UIImage) {
        func showError() {
            DispatchQueue.main.async {
                self.destination = .errorOpeningFile(message: T.vaultRecoveryErrorScanningFile) { [weak self] in
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
                    if let masterKey = parseResult.masterKey {
                        switch self.flowContext.kind {
                        case .onboarding:
                            self.destination = .vaultRecovery(
                                entropy: parseResult.entropy,
                                masterKey: masterKey,
                                recoveryData: self.recoveryData
                            )
                        case .importVault:
                            switch self.recoveryData {
                            case .cloud:
                                fatalError("Unsupported importing vault from cloud")
                            case .file(let file):
                                self.destination = .importVault(
                                    .encrypted(entropy: parseResult.entropy, masterKey: masterKey, vault: file),
                                    onClose: self.flowContext.onClose ?? {}
                                )
                            }
                        }
                    } else {
                        self.destination = .enterMasterPassword(
                            flowContext: self.flowContext,
                            entropy: parseResult.entropy,
                            recoveryData: self.recoveryData
                        )
                    }
                }
            case .failure:
                showError()
            }
        }
    }
}
