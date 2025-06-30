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
    
    private(set) var isExporting = false
    
    private var exportingTask: Task<Void, Never>?
    
    private let interactor: BackupExportFileModuleInteracting
    private let onClose: Callback
    
    init(interactor: BackupExportFileModuleInteracting, onClose: @escaping Callback) {
        self.interactor = interactor
        self.onClose = onClose
    }
}

extension BackupExportFilePresenter {
    
    func onExport() {
        isExporting = true
        exportingTask = Task {
            do {
                let url = try await interactor.export(encrypt: encryptFile)
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
