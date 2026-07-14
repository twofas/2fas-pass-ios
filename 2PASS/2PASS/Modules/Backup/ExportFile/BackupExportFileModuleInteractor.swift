// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

protocol BackupExportFileModuleInteracting: AnyObject {
    var defaultVaultID: VaultID? { get }
    func listVaults() -> [VaultData]
    func export(vaultID: VaultID, encrypt: Bool) async throws -> URL
    func clear()
}

final class BackupExportFileModuleInteractor {
    private let exportInteractor: ExportInteracting
    private let vaultsInteractor: VaultsInteracting

    private var fileURL: URL?
    private let currentDateInteractor: CurrentDateInteracting

    init(exportInteractor: ExportInteracting, vaultsInteractor: VaultsInteracting, currentDateInteractor: CurrentDateInteracting) {
        self.exportInteractor = exportInteractor
        self.vaultsInteractor = vaultsInteractor
        self.currentDateInteractor = currentDateInteractor
    }
}

extension BackupExportFileModuleInteractor: BackupExportFileModuleInteracting {

    var defaultVaultID: VaultID? {
        vaultsInteractor.defaultVaultID
    }

    func listVaults() -> [VaultData] {
        vaultsInteractor.listVaults()
    }

    func export(vaultID: VaultID, encrypt: Bool) async throws -> URL {
        let vault = try await exportInteractor.prepareItemsForExport(
            vaultID: vaultID,
            encrypt: encrypt,
            exportIfEmpty: false,
            includeDeletedItems: false
        )
        let data = try JSONEncoder().encode(vault)
        let url = try saveFile(data, vaultName: vault.vault.name)
        fileURL = url
        return url
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
