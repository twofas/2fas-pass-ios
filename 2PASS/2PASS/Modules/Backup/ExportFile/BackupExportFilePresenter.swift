// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common

enum BackupExportFileDestination: RouterDestination {
    case shareFile(URL, onComplete: Callback, onError: Callback)
    case success(onClose: Callback)
    case failure(onClose: Callback)
    
    var id: String {
        switch self {
        case .shareFile: "shareFile"
        case .success: "success"
        case .failure: "failure"
        }
    }
}

@Observable @MainActor
final class BackupExportFilePresenter {

    var destination: BackupExportFileDestination?
    var encryptFile = true
    var selectedVaultID: VaultID

    let availableVaults: [VaultData]

    var hasMultipleVaults: Bool {
        availableVaults.count > 1
    }

    private(set) var isExporting = false

    private var exportingTask: Task<Void, Never>?

    private let interactor: BackupExportFileModuleInteracting
    private let onClose: Callback

    init(interactor: BackupExportFileModuleInteracting, onClose: @escaping Callback) {
        self.interactor = interactor
        self.onClose = onClose

        let nonEmptyVaults = interactor.listVaults().filter { !$0.isEmpty }
        self.availableVaults = nonEmptyVaults

        let defaultVaultID = interactor.defaultVaultID
        self.selectedVaultID = nonEmptyVaults.contains(where: { $0.vaultID == defaultVaultID })
            ? defaultVaultID
            : (nonEmptyVaults.first?.vaultID ?? defaultVaultID)
    }
}

extension BackupExportFilePresenter {
    
    func onExport() {
        isExporting = true
        exportingTask = Task {
            do {
                let url = try await interactor.export(vaultID: selectedVaultID, encrypt: encryptFile)
                isExporting = false
                
                try Task.checkCancellation()
                
                destination = .shareFile(url, onComplete: { [weak self] in
                    self?.toSuccess()
                }, onError: { [weak self] in
                    self?.toFailure()
                })
            } catch {
                toFailure()
            }
        }
    }
    
    func onDisappear() {
        exportingTask?.cancel()
        exportingTask = nil
        
        interactor.clear()
    }
    
    private func toSuccess() {
        destination = .success(onClose: onClose)
    }
    
    private func toFailure() {
        destination = .failure(onClose: onClose)
    }
}
