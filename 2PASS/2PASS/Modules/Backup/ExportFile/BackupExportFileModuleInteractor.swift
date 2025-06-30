// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

protocol BackupExportFileModuleInteracting: AnyObject {
    func export(encrypt: Bool) async throws -> URL
    func clear()
}

final class BackupExportFileModuleInteractor {
    private let exportInteractor: ExportInteracting

    private var fileURL: URL?
    private let currentDateInteractor: CurrentDateInteracting
    
    init(exportInteractor: ExportInteracting, currentDateInteractor: CurrentDateInteracting) {
        self.exportInteractor = exportInteractor
        self.currentDateInteractor = currentDateInteractor
    }
}

extension BackupExportFileModuleInteractor: BackupExportFileModuleInteracting {
    
    func export(encrypt: Bool) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            self.exportInteractor.preparePasswordsForExport(encrypt: encrypt, exportIfEmpty: false, includeDeletedItems: false) { result in
                switch result {
                case .success(let data):
                    do {                    
                        let url = try self.saveFile(data.0, vaultName: data.1)
                        self.fileURL = url
                        continuation.resume(returning: url)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    Log("BackupExportSaveFileModuleInteractor - Error while exporting: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func clear() {
        if let fileURL {
            do {
                try FileManager.default.removeItem(at: fileURL)
            } catch {
                Log(
                    "BackupExportSaveFileModuleInteractor: Can't delete Vault export fileat path: \(fileURL), error: \(error)",
                    module: .moduleInteractor
                )
            }
        }
    }
    
    private func saveFile(_ data: Data, vaultName: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = "Vault \(vaultName.sanitizeForFileName()) (\(currentDateInteractor.currentDate.fileDateAndTime())).2faspass"
        let fileURL = tempDir.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL)
            return fileURL
        } catch {
            Log(
                "BackupExportSaveFileModuleInteractor: Can't write generated Vault export file to \(fileURL), error: \(error)",
                module: .moduleInteractor
            )
            throw error
        }
    }
}
