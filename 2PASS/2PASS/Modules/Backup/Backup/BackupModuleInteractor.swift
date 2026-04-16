// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

enum BackupModuleImportResult {
    case decrypted([ItemDecryptedData], tags: [ItemTagData], deleted: [DeletedItemData])
    case encrypted(ExchangeVaultVersioned, entropy: Entropy?)
}

protocol BackupModuleInteracting: AnyObject {
    var currentPlanItemsLimit: Int { get }
    var canImport: Bool { get }
    var hasItems: Bool { get }

    func loginUsingBiometryIfAvailable() async -> Bool

    func openFile(url: URL) async throws(BackupImportFileError) -> Data
    func parseContents(of data: Data) async throws -> BackupModuleImportResult
    func isVaultInitialized() -> Bool
}

final class BackupModuleInteractor {
    private let importInteractor: BackupImportInteracting
    private let itemsInteractor: ItemsInteracting
    private let biometryInteractor: BiometryInteracting
    private let loginInteractor: LoginInteracting
    private let protectionInteractor: ProtectionInteracting
    private let paymentStatusInteractor: PaymentStatusInteracting
    
    init(importInteractor: BackupImportInteracting, itemsInteractor: ItemsInteracting, biometryInteractor: BiometryInteracting, loginInteractor: LoginInteracting, protectionInteractor: ProtectionInteracting, paymentStatusInteractor: PaymentStatusInteracting) {
        self.importInteractor = importInteractor
        self.itemsInteractor = itemsInteractor
        self.biometryInteractor = biometryInteractor
        self.loginInteractor = loginInteractor
        self.protectionInteractor = protectionInteractor
        self.paymentStatusInteractor = paymentStatusInteractor
    }
}

extension BackupModuleInteractor: BackupModuleInteracting {
    
    var hasItems: Bool {
        itemsInteractor.hasItems
    }
    
    var canImport: Bool {
        guard let limit = paymentStatusInteractor.entitlements.itemsLimit else {
            return true
        }
        return itemsInteractor.itemsCount < limit
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
    
    func openFile(url: URL) async throws(BackupImportFileError) -> Data {
        try await importInteractor.openFile(url: url)
    }

    func isVaultInitialized() -> Bool {
        importInteractor.isVaultReadyForImport()
    }

    func parseContents(of data: Data) async throws -> BackupModuleImportResult {
        let importResult = try await importInteractor.parseContents(
            of: data, decryptItemsIfPossible: false, preferCurrentVaultEncryption: false, allowsAnyDeviceId: true
        )

        switch importResult {
        case .decrypted(let items, let tags, let deleted, _, _, _, _):
            return .decrypted(items, tags: tags, deleted: deleted)
        case .encryptedForCurrentVault:
            assertionFailure("encryptedForCurrentVault unreachable when decryptItemsIfPossible == false")
            throw BackupImportParseError.errorDecrypting
        case .needsPassword(let vault, let currentSeed, _, _, _, _):
            let entropy: Entropy? = {
                if currentSeed {
                    protectionInteractor.restoreEntropy()
                    let entropy = protectionInteractor.entropy
                    protectionInteractor.clearEntropy()
                    return entropy
                }
                return nil
            }()
            return .encrypted(vault, entropy: entropy)
        }
    }
}
