// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

protocol VaultRecoveryCheckModuleInteracting: AnyObject {
    var url: URL { get }
    func openFile() async throws(BackupImportFileError) -> Data
    func parseContents(of data: Data) async throws -> BackupImportWithoutEncryptionResult
    func parseItems(_ exchangeVault: ExchangeVaultVersioned) -> [ItemData]?
}

final class VaultRecoveryCheckModuleInteractor {
    private let importInteractor: BackupImportInteracting
    let url: URL
    
    init(importInteractor: BackupImportInteracting, url: URL) {
        self.importInteractor = importInteractor
        self.url = url
    }
}

extension VaultRecoveryCheckModuleInteractor: VaultRecoveryCheckModuleInteracting {
    func openFile() async throws(BackupImportFileError) -> Data {
        try await importInteractor.openFile(url: url)
    }

    func parseContents(of data: Data) async throws -> BackupImportWithoutEncryptionResult {
        try await importInteractor.parseContentsWithoutEncryption(of: data)
    }
    
    func parseItems(_ exchangeVault: ExchangeVaultVersioned) -> [ItemData]? {
        importInteractor.extractItems(from: exchangeVault)
    }
}
