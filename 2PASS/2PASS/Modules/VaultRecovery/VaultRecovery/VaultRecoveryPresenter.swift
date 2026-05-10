// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common

enum VaultRecoveryDestination: Identifiable {
    var id: String {
        switch self {
        case .selectFile: "selectFile"
        case .restoreFromFile(let url, _): "restoreFromFile\(url.absoluteString)"
        case .selectiCloudVault: "restoreFromiCloud"
        case .restoreFromWebDAV: "restoreFromWebDAV"
        case .restoreFromS3: "restoreFromS3"
        case .restore: "select"
        case .errorReadingFile: "errorReadingFile"
        }
    }

    case selectFile(onClose: (FileImportResult) -> Void)
    case restoreFromFile(url: URL, onClose: Callback)
    case selectiCloudVault(onSelect: (VaultRecoveryData) -> Void)
    case restoreFromWebDAV(onSelect: (VaultRecoveryData) -> Void)
    case restoreFromS3(onSelect: (VaultRecoveryData) -> Void)
    case restore(VaultRecoveryData, onClose: Callback)
    case errorReadingFile
}

@Observable
final class VaultRecoveryPresenter {
    var destination: VaultRecoveryDestination?
    
    var showCantReadFileAlert = false
    
    private let interactor: VaultRecoveryModuleInteracting
    
    init(interactor: VaultRecoveryModuleInteracting) {
        self.interactor = interactor
    }
}

extension VaultRecoveryPresenter {
    func onRestoreFromFile() {
        destination = .selectFile(onClose: { [weak self] result in
            switch result {
            case .cantReadFile: self?.destination = .errorReadingFile
            case .fileOpen(let url):
                self?.destination = .restoreFromFile(url: url, onClose: { [weak self] in
                    self?.destination = nil
                })
            case .cancelled: self?.destination = nil
            }
        })
    }
    
    func onRestoreFromWebDAV() {
        destination = .restoreFromWebDAV(onSelect: { [weak self] selected in
            self?.destination = nil

            Task { @MainActor in
                try await Task.sleep(for: .milliseconds(900))

                guard let self else { return }
                self.destination = .restore(selected, onClose: { [weak self] in
                    self?.destination = nil
                })
            }
        })
    }

    func onRestoreFromS3() {
        destination = .restoreFromS3(onSelect: { [weak self] selected in
            self?.destination = nil

            Task { @MainActor in
                try await Task.sleep(for: .milliseconds(900))

                guard let self else { return }
                self.destination = .restore(selected, onClose: { [weak self] in
                    self?.destination = nil
                })
            }
        })
    }

    func onRestoreFromCloud() {
        destination = .selectiCloudVault(onSelect: { [weak self] selected in
            self?.destination = nil
            
            Task { @MainActor in
                try await Task.sleep(for: .milliseconds(900))
                
                guard let self else { return }
                self.destination = .restore(selected, onClose: { [weak self] in
                    self?.destination = nil
                })
            }
        })
    }
}
