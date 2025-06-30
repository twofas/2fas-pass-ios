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
    func openFile(completion: @escaping (Result<Data, BackupImportFileError>) -> Void)
    func parseContents(
        of data: Data,
        completion: @escaping (Result<BackupImportWithoutEncryptionResult, BackupImportParseError>) -> Void
    )
    func parsePasswords(_ exchangeVault: ExchangeVault) -> [PasswordData]?
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
    func openFile(completion: @escaping (Result<Data, BackupImportFileError>) -> Void) {
        importInteractor.openFile(url: url, completion: completion)
    }
    
    func parseContents(
        of data: Data,
        completion: @escaping (Result<BackupImportWithoutEncryptionResult, BackupImportParseError>) -> Void
    ) {
        importInteractor.parseContentsWithoutEncryption(of: data, completion: completion)
    }
    
    func parsePasswords(_ exchangeVault: ExchangeVault) -> [PasswordData]? {
        importInteractor.extractPasswords(from: exchangeVault)
    }
}
