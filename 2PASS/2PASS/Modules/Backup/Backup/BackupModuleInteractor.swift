// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

enum BackupModuleImportResult {
    case decrypted([ItemData], tags: [ItemTagData], deleted: [DeletedItemData])
    case encrypted(ExchangeVault, entropy: Entropy?)
}

protocol BackupModuleInteracting: AnyObject {
    var currentPlanItemsLimit: Int { get }
    var canImport: Bool { get }
    var hasPasswords: Bool { get }

    func loginUsingBiometryIfAvailable() async -> Bool
    
    func openFile(url: URL, completion: @escaping (Result<Data, BackupImportFileError>) -> Void)
    func parseContents(
        of data: Data,
        completion: @escaping (Result<BackupModuleImportResult, BackupImportParseError>) -> Void
    )
    func isVaultInitialized() -> Bool
}

final class BackupModuleInteractor {
    private let importInteractor: BackupImportInteracting
    private let passwordInteractor: PasswordInteracting
    private let biometryInteractor: BiometryInteracting
    private let loginInteractor: LoginInteracting
    private let protectionInteractor: ProtectionInteracting
    private let paymentStatusInteractor: PaymentStatusInteracting
    
    init(importInteractor: BackupImportInteracting, passwordInteractor: PasswordInteracting, biometryInteractor: BiometryInteracting, loginInteractor: LoginInteracting, protectionInteractor: ProtectionInteracting, paymentStatusInteractor: PaymentStatusInteracting) {
        self.importInteractor = importInteractor
        self.passwordInteractor = passwordInteractor
        self.biometryInteractor = biometryInteractor
        self.loginInteractor = loginInteractor
        self.protectionInteractor = protectionInteractor
        self.paymentStatusInteractor = paymentStatusInteractor
    }
}

extension BackupModuleInteractor: BackupModuleInteracting {
    
    var hasPasswords: Bool {
        passwordInteractor.hasItems
    }
    
    var canImport: Bool {
        guard let limit = paymentStatusInteractor.entitlements.itemsLimit else {
            return true
        }
        return passwordInteractor.itemsCount < limit
    }
    
    var currentPlanItemsLimit: Int {
        paymentStatusInteractor.entitlements.itemsLimit ?? Int.max
    }
    
    func loginUsingBiometryIfAvailable() async -> Bool {
        guard biometryInteractor.canUseBiometryForLogin else {
            return false
        }
        
        return await withCheckedContinuation { continuation in
            loginInteractor.loginUsingBiometry(reason: "Verify master password") { result in
                switch result {
                case .success:
                    continuation.resume(returning: true)
                default:
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    func openFile(url: URL, completion: @escaping (Result<Data, BackupImportFileError>) -> Void) {
        importInteractor.openFile(url: url, completion: completion)
    }
    
    func isVaultInitialized() -> Bool {
        importInteractor.isVaultReadyForImport()
    }
    
    func parseContents(
        of data: Data,
        completion: @escaping (Result<BackupModuleImportResult, BackupImportParseError>) -> Void
    ) {
        importInteractor.parseContents(of: data, decryptPasswordsIfPossible: false, allowsAnyDeviceId: true) { [weak self] result in
            guard let self else { return }
            
            switch result {
            case .success(let importResult):
                switch importResult {
                case .decrypted(let passwords, let tags, let deleted, _, _, _, _):
                    completion(.success(.decrypted(passwords, tags: tags, deleted: deleted)))
                case .needsPassword(let vault, let currentSeed, _, _, _, _):
                    let entropy: Entropy? = {
                        if currentSeed {
                            self.protectionInteractor.restoreEntropy()
                            let entropy = self.protectionInteractor.entropy
                            self.protectionInteractor.clearEntropy()
                            return entropy
                        }
                        return nil
                    }()
                    completion(.success(.encrypted(vault, entropy: entropy)))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
