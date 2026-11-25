// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CryptoKit
import Common
@testable import Data

/// Defaults describe an unlocked, set-up app: every check passes, every optional value but the master key is `nil`.
final class MockProtectionInteractor: ProtectionInteracting, CallTrackingMock {

    // MARK: - Call Tracking

    var methodCalls: [String] = []
    let callLog: MockCallLog?

    init(callLog: MockCallLog? = nil) {
        self.callLog = callLog
    }

    // MARK: - Stub Configuration

    private var stubbedVerifyMasterPassword: (String) -> Bool = { _ in true }
    private var stubbedVerifyMasterKey: (MasterKey) -> Bool = { _ in true }
    private var stubbedMasterKey: MasterKey?
    private var stubbedEntropy: Entropy?
    private var stubbedHasVault = true

    @discardableResult
    func withVerifyMasterPassword(_ handler: @escaping (String) -> Bool) -> Self {
        stubbedVerifyMasterPassword = handler
        return self
    }

    @discardableResult
    func withVerifyMasterKey(_ handler: @escaping (MasterKey) -> Bool) -> Self {
        stubbedVerifyMasterKey = handler
        return self
    }

    @discardableResult
    func withMasterKey(_ value: MasterKey?) -> Self {
        stubbedMasterKey = value
        return self
    }

    @discardableResult
    func withEntropy(_ value: Entropy?) -> Self {
        stubbedEntropy = value
        return self
    }

    @discardableResult
    func withHasVault(_ value: Bool) -> Self {
        stubbedHasVault = value
        return self
    }

    // MARK: - ProtectionInteracting properties

    var hasDeviceID: Bool { true }
    var words: [String]? { nil }
    var seed: Seed? { nil }
    var salt: Salt? { nil }
    var masterKey: MasterKey? { stubbedMasterKey }
    var masterPassword: String? { nil }
    var entropy: Entropy? { stubbedEntropy }
    var hasVault: Bool { stubbedHasVault }
    var vaultHasTrustedItems: Bool { false }
    var hasEncryptedEntropy: Bool { true }
    var hasBiometryKey: Bool { true }
    var hasAppKey: Bool { true }
    var hasEncryptionReference: Bool { true }

    // MARK: - ProtectionInteracting functions

    func setupDeviceID() {
        recordCall()
    }

    func restoreEntropy() {
        recordCall()
    }

    func saveEntropy() {
        recordCall()
    }

    func clearEntropy() {
        recordCall()
    }

    func clearApp() {
        recordCall()
    }

    func createAppKey(completion: @escaping (Bool) -> Void) {
        recordCall()
        completion(true)
    }

    func verifyAppKey() -> Bool {
        recordCall()
        return true
    }

    func generateEntropy() {
        recordCall()
    }

    func createSeed() {
        recordCall()
    }

    func createSalt() {
        recordCall()
    }

    func verifyMasterPassword(_ masterPassword: String) -> Bool {
        recordCall()
        return stubbedVerifyMasterPassword(masterPassword)
    }

    func setMasterKey(for masterPassword: String) {
        recordCall()
    }

    func setMasterKey(_ masterKey: MasterKey) {
        recordCall()
        stubbedMasterKey = masterKey
    }

    func setMasterPassword(_ masterPassword: MasterPassword) {
        recordCall()
    }

    func masterKey(from masterPassword: MasterPassword, entropy: Entropy) -> MasterKey? {
        recordCall()
        return stubbedMasterKey
    }

    func masterKey(from masterPassword: MasterPassword, entropy: Entropy, kdfSpec: KDFSpec) -> MasterKey? {
        recordCall()
        return stubbedMasterKey
    }

    func setupKeys() {
        recordCall()
    }

    func selectVault() {
        recordCall()
    }

    func clearAfterInit() {
        recordCall()
    }

    func clearAfterLogin() {
        recordCall()
    }

    func updateExistingVault() {
        recordCall()
    }

    func setShouldRetainEncryptionDataAfterLogin(_ shouldRetain: Bool) {
        recordCall()
    }

    func createNewVault(with vaultID: VaultID, creationDate: Date?, modificationDate: Date?) {
        recordCall()
    }

    func saveEncryptionReference() {
        recordCall()
    }

    func getAllWords() -> [String] {
        recordCall()
        return []
    }

    func setWords(_ words: [String], masterPassword: MasterPassword?) -> Result<Void, SetWordsError> {
        recordCall()
        return .success(())
    }

    func setEntropy(_ entropy: Entropy, masterKey: MasterKey?) -> Bool {
        recordCall()
        return true
    }

    func wordsToEntropy(_ words: [String]) -> Entropy? {
        recordCall()
        return nil
    }

    func recreateSeedSaltWordsMasterKey() -> Bool {
        recordCall()
        return true
    }

    func clearAppKeyStorage() {
        recordCall()
    }

    func clearMasterKey() {
        recordCall()
        stubbedMasterKey = nil
    }

    func clearMasterKeyEncrypted() {
        recordCall()
    }

    func clearAppKeyEncryptedStorage() {
        recordCall()
    }

    func createExternalSymmetricKey(from masterKey: MasterKey, vaultID: VaultID) -> SymmetricKey? {
        recordCall()
        return nil
    }

    func verifyMasterKeyUsingVault(_ masterKey: MasterKey) -> Bool {
        recordCall()
        return stubbedVerifyMasterKey(masterKey)
    }

    func verifyMasterKey(_ masterKey: MasterKey) -> Bool {
        recordCall()
        return stubbedVerifyMasterKey(masterKey)
    }

    func validateEntropyMatchesCurrentVault(_ entropy: Entropy) -> Bool {
        recordCall()
        return true
    }
}
