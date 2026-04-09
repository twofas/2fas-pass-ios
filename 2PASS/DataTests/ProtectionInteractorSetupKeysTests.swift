// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Testing
import Foundation
import Common
@testable import Data

/// Full-coverage unit tests for `ProtectionInteractor.setupKeys()` and its
/// helper `deriveAndCacheKeys(for:using:)`. Exercises every observable
/// branch so future refactors cannot silently regress unlock behavior:
/// master-key presence check, metadata key derivation (success / nil /
/// invalid-hex), empty vault list early return, single- and multi-vault
/// happy paths, per-vault failure modes at each of trusted / secure /
/// external key generation, generator-arg shape (hex-encoded master key),
/// and multi-vault loop continuation across a single-vault failure.
@Suite("ProtectionInteractor.setupKeys")
struct ProtectionInteractorSetupKeysTests {

    // MARK: - Fixtures

    private static let masterKeyBytes = Data(repeating: 0xAB, count: 32)
    private static let masterKeyHex = masterKeyBytes.hexEncodedString()

    private static let metadataHex = String(repeating: "0c", count: 32)
    private static let trustedHex  = String(repeating: "0a", count: 32)
    private static let secureHex   = String(repeating: "0b", count: 32)
    private static let externalHex = String(repeating: "0d", count: 32)

    private func makeVault(id: VaultID = UUID()) -> VaultEncryptedData {
        VaultEncryptedData(
            vaultID: id,
            name: Data(),
            trustedKey: Data(),
            createdAt: Date(),
            updatedAt: Date(),
            isEmpty: false,
            color: nil,
            icon: nil
        )
    }

    /// Wires a mock so all three per-vault key generators return valid hex.
    /// Returns the mock pre-configured with a master key and metadata
    /// generator, ready for additional overrides.
    private func makeHappyRepository() -> MockMainRepository {
        MockMainRepository()
            .withEmpheralMasterKey(Self.masterKeyBytes)
            .withGenerateMetadataKey { _ in Self.metadataHex }
            .withGenerateTrustedKeyForVaultID  { _, _ in Self.trustedHex  }
            .withGenerateSecureKeyForVaultID   { _, _ in Self.secureHex   }
            .withGenerateExternalKeyForVaultID { _, _ in Self.externalHex }
    }

    private func makeInteractor(
        repository: MockMainRepository,
        vaults: MockVaultsInteractor = MockVaultsInteractor()
    ) -> ProtectionInteractor {
        ProtectionInteractor(
            mainRepository: repository,
            vaultsInteractor: vaults,
            storageInteractor: StubStorageInteractor()
        )
    }

    // MARK: - Metadata key branches

    /// Happy path: derived metadata key is stored and cached.
    @Test
    func setupKeysDerivesAndStoresMetadataKey() {
        let repository = makeHappyRepository()
        let interactor = makeInteractor(repository: repository)

        interactor.setupKeys()

        let expected = Data(hexString: Self.metadataHex)
        #expect(repository.capturedMetadataKey != nil)
        #expect(repository.capturedMetadataKey == expected)
        #expect(repository.wasCalled(MethodName.generateMetadataKey))
        #expect(repository.wasCalled(MethodName.setMetadataKey))
        #expect(repository.wasCalled(MethodName.prepareMetadataCache))
    }

    /// Derivation returns nil: log, skip, do NOT call the cache helper
    /// (avoids a misleading "can't prepare cache" log piled on top of the
    /// real "generation failed" log).
    @Test
    func setupKeysDoesNotAbortWhenMetadataKeyDerivationFails() {
        let repository = MockMainRepository()
            .withEmpheralMasterKey(Self.masterKeyBytes)
            .withGenerateMetadataKey { _ in nil }
        let interactor = makeInteractor(repository: repository)

        interactor.setupKeys()

        #expect(repository.capturedMetadataKey == nil)
        #expect(repository.wasCalled(MethodName.prepareMetadataCache) == false)
    }

    /// Derivation returns an unparseable hex string. `Data(hexString:)`
    /// fails, metadata setup is skipped, and the vault loop still runs to
    /// completion — a bad metadata key must never prevent vault unlock.
    @Test
    func setupKeysSkipsMetadataWhenHexDecodeFails() {
        let vaultID = UUID()
        let repository = makeHappyRepository()
            .withGenerateMetadataKey { _ in "zz" } // even-length but invalid hex bytes

        let vaults = MockVaultsInteractor()
            .withListEncryptedVaults([makeVault(id: vaultID)])
        let interactor = makeInteractor(repository: repository, vaults: vaults)

        interactor.setupKeys()

        #expect(repository.capturedMetadataKey == nil)
        #expect(repository.wasCalled(MethodName.prepareMetadataCache) == false)
        // Vault loop must still run even though metadata derivation failed.
        #expect(repository.callCount(MethodName.setTrustedKey)  == 1)
        #expect(repository.callCount(MethodName.setSecureKey)   == 1)
        #expect(repository.callCount(MethodName.setExternalKey) == 1)
        #expect(repository.callCount(MethodName.preparedCachedKeys)    == 1)
    }

    // MARK: - Master key / vault list gating

    /// No master key in memory: bail immediately, nothing is touched.
    @Test
    func setupKeysReturnsEarlyWhenMasterKeyMissing() {
        // Intentionally no `withEmpheralMasterKey(...)` — stays nil.
        let repository = MockMainRepository()
            .withGenerateMetadataKey { _ in Self.metadataHex }
            .withGenerateTrustedKeyForVaultID  { _, _ in Self.trustedHex  }
            .withGenerateSecureKeyForVaultID   { _, _ in Self.secureHex   }
            .withGenerateExternalKeyForVaultID { _, _ in Self.externalHex }

        let vaults = MockVaultsInteractor()
            .withListEncryptedVaults([makeVault()])
        let interactor = makeInteractor(repository: repository, vaults: vaults)

        interactor.setupKeys()

        #expect(repository.wasCalled(MethodName.generateMetadataKey)         == false)
        #expect(repository.wasCalled(MethodName.setMetadataKey)                  == false)
        #expect(repository.wasCalled(MethodName.prepareMetadataCache)           == false)
        #expect(repository.callCount(MethodName.setTrustedKey)          == 0)
        #expect(repository.callCount(MethodName.setSecureKey)           == 0)
        #expect(repository.callCount(MethodName.setExternalKey)         == 0)
        #expect(repository.callCount(MethodName.preparedCachedKeys)            == 0)
    }

    /// Metadata succeeds but no vaults exist: metadata is installed,
    /// then the function bails before deriving any per-vault keys.
    @Test
    func setupKeysStopsAfterMetadataWhenNoVaults() {
        let repository = makeHappyRepository()
        // No .withListEncryptedVaults — default is [].
        let interactor = makeInteractor(repository: repository)

        interactor.setupKeys()

        #expect(repository.capturedMetadataKey != nil)
        #expect(repository.wasCalled(MethodName.prepareMetadataCache))
        #expect(repository.callCount(MethodName.setTrustedKey)  == 0)
        #expect(repository.callCount(MethodName.setSecureKey)   == 0)
        #expect(repository.callCount(MethodName.setExternalKey) == 0)
        #expect(repository.callCount(MethodName.preparedCachedKeys)    == 0)
    }

    // MARK: - Vault key happy paths

    /// One vault, all three key generations succeed: all three setters
    /// plus `preparedCachedKeys` run.
    @Test
    func setupKeysDerivesFullKeySetForSingleVault() {
        let repository = makeHappyRepository()
        let vaults = MockVaultsInteractor()
            .withListEncryptedVaults([makeVault()])
        let interactor = makeInteractor(repository: repository, vaults: vaults)

        interactor.setupKeys()

        #expect(repository.callCount(MethodName.setTrustedKey)  == 1)
        #expect(repository.callCount(MethodName.setSecureKey)   == 1)
        #expect(repository.callCount(MethodName.setExternalKey) == 1)
        #expect(repository.callCount(MethodName.preparedCachedKeys)    == 1)
    }

    /// Two distinct vaults, both fully derived. Uses the generator
    /// closures as a recording mechanism because
    /// `MockMainRepository.capturedTrustedKey` is singular and loses
    /// per-vault history across calls. Also asserts each generator saw
    /// the correct vault ID and the hex-encoded master key.
    @Test
    func setupKeysDerivesKeysForEveryVault() {
        let vaultA = UUID()
        let vaultB = UUID()

        // Reference-typed collectors so the escaping generator closures
        // can mutate them despite struct `self` being immutable.
        let trustedCalls  = Ref<[(VaultID, String)]>([])
        let secureCalls   = Ref<[(VaultID, String)]>([])
        let externalCalls = Ref<[(VaultID, String)]>([])

        let repository = MockMainRepository()
            .withEmpheralMasterKey(Self.masterKeyBytes)
            .withGenerateMetadataKey { _ in Self.metadataHex }
            .withGenerateTrustedKeyForVaultID { vaultID, masterKeyHex in
                trustedCalls.value.append((vaultID, masterKeyHex))
                return Self.trustedHex
            }
            .withGenerateSecureKeyForVaultID { vaultID, masterKeyHex in
                secureCalls.value.append((vaultID, masterKeyHex))
                return Self.secureHex
            }
            .withGenerateExternalKeyForVaultID { vaultID, masterKeyHex in
                externalCalls.value.append((vaultID, masterKeyHex))
                return Self.externalHex
            }

        let vaults = MockVaultsInteractor()
            .withListEncryptedVaults([makeVault(id: vaultA), makeVault(id: vaultB)])
        let interactor = makeInteractor(repository: repository, vaults: vaults)

        interactor.setupKeys()

        // Each setter was called exactly twice — once per vault.
        #expect(repository.callCount(MethodName.setTrustedKey)  == 2)
        #expect(repository.callCount(MethodName.setSecureKey)   == 2)
        #expect(repository.callCount(MethodName.setExternalKey) == 2)
        #expect(repository.callCount(MethodName.preparedCachedKeys) == 2)

        // Each generator saw both vault IDs, exactly once each. The count
        // check is not redundant with the Set equality — a Set would
        // collapse [A, A] into {A} and falsely pass.
        #expect(Set(trustedCalls.value.map  { $0.0 }) == Set([vaultA, vaultB]))
        #expect(Set(secureCalls.value.map   { $0.0 }) == Set([vaultA, vaultB]))
        #expect(Set(externalCalls.value.map { $0.0 }) == Set([vaultA, vaultB]))
        #expect(trustedCalls.value.count  == 2)
        #expect(secureCalls.value.count   == 2)
        #expect(externalCalls.value.count == 2)

        // Every generator was handed the hex-encoded master key.
        let expectedHex = Self.masterKeyHex
        #expect(trustedCalls.value.allSatisfy  { $0.1 == expectedHex })
        #expect(secureCalls.value.allSatisfy   { $0.1 == expectedHex })
        #expect(externalCalls.value.allSatisfy { $0.1 == expectedHex })
    }

    // MARK: - Per-vault failure modes (`deriveAndCacheKeys`)

    /// Trusted key generation fails: the per-vault helper bails before
    /// touching *any* setter.
    @Test
    func setupKeysStopsVaultWhenTrustedKeyFails() {
        let repository = makeHappyRepository()
            .withGenerateTrustedKeyForVaultID { _, _ in nil }
        let vaults = MockVaultsInteractor()
            .withListEncryptedVaults([makeVault()])
        let interactor = makeInteractor(repository: repository, vaults: vaults)

        interactor.setupKeys()

        #expect(repository.callCount(MethodName.setTrustedKey)  == 0)
        #expect(repository.callCount(MethodName.setSecureKey)   == 0)
        #expect(repository.callCount(MethodName.setExternalKey) == 0)
        #expect(repository.callCount(MethodName.preparedCachedKeys)    == 0)
    }

    /// Trusted OK but secure fails: only `setTrustedKey` was invoked.
    /// Guards against a future refactor that "helpfully" caches
    /// whichever partial keys succeeded.
    @Test
    func setupKeysStopsVaultWhenSecureKeyFails() {
        let repository = makeHappyRepository()
            .withGenerateSecureKeyForVaultID { _, _ in nil }
        let vaults = MockVaultsInteractor()
            .withListEncryptedVaults([makeVault()])
        let interactor = makeInteractor(repository: repository, vaults: vaults)

        interactor.setupKeys()

        #expect(repository.callCount(MethodName.setTrustedKey)  == 1)
        #expect(repository.callCount(MethodName.setSecureKey)   == 0)
        #expect(repository.callCount(MethodName.setExternalKey) == 0)
        #expect(repository.callCount(MethodName.preparedCachedKeys)    == 0)
    }

    /// Trusted + secure OK, external fails: `setTrustedKey` and
    /// `setSecureKey` ran but no `setExternalKey` / `preparedCachedKeys`.
    @Test
    func setupKeysStopsVaultWhenExternalKeyFails() {
        let repository = makeHappyRepository()
            .withGenerateExternalKeyForVaultID { _, _ in nil }
        let vaults = MockVaultsInteractor()
            .withListEncryptedVaults([makeVault()])
        let interactor = makeInteractor(repository: repository, vaults: vaults)

        interactor.setupKeys()

        #expect(repository.callCount(MethodName.setTrustedKey)  == 1)
        #expect(repository.callCount(MethodName.setSecureKey)   == 1)
        #expect(repository.callCount(MethodName.setExternalKey) == 0)
        #expect(repository.callCount(MethodName.preparedCachedKeys)    == 0)
    }

    // MARK: - Multi-vault partial failure

    /// Two vaults; the first vault's trusted-key derivation fails but
    /// the second vault succeeds end-to-end. Proves the `for vault in
    /// vaults` loop in `setupKeys` does NOT abort the entire unlock
    /// when a single vault's key derivation fails — the user shouldn't
    /// lose access to every vault because one went bad.
    @Test
    func setupKeysContinuesVaultDerivationAcrossPartialFailure() {
        let failingVault = UUID()
        let healthyVault = UUID()

        let repository = makeHappyRepository()
            .withGenerateTrustedKeyForVaultID { vaultID, _ in
                vaultID == failingVault ? nil : Self.trustedHex
            }

        let vaults = MockVaultsInteractor()
            .withListEncryptedVaults([
                makeVault(id: failingVault),
                makeVault(id: healthyVault)
            ])
        let interactor = makeInteractor(repository: repository, vaults: vaults)

        interactor.setupKeys()

        // Failing vault produced no setters; healthy vault produced a full set.
        // Net: exactly one of each.
        #expect(repository.callCount(MethodName.setTrustedKey)  == 1)
        #expect(repository.callCount(MethodName.setSecureKey)   == 1)
        #expect(repository.callCount(MethodName.setExternalKey) == 1)
        #expect(repository.callCount(MethodName.preparedCachedKeys)    == 1)
    }

    // MARK: - Arg shape

    /// Every generator sees the hex-encoded master key, not raw bytes.
    /// Guards against a regression where `setupKeys` accidentally passes
    /// `masterKey` instead of `masterKey.hexEncodedString()`, which would
    /// silently derive different keys.
    @Test
    func setupKeysPassesHexEncodedMasterKeyToGenerators() {
        let metadataArg = Ref<String?>(nil)
        let trustedArg  = Ref<String?>(nil)

        let repository = makeHappyRepository()
            .withGenerateMetadataKey { masterKeyHex in
                metadataArg.value = masterKeyHex
                return Self.metadataHex
            }
            .withGenerateTrustedKeyForVaultID { _, masterKeyHex in
                trustedArg.value = masterKeyHex
                return Self.trustedHex
            }

        let vaults = MockVaultsInteractor()
            .withListEncryptedVaults([makeVault()])
        let interactor = makeInteractor(repository: repository, vaults: vaults)

        interactor.setupKeys()

        let expectedHex = Self.masterKeyHex
        #expect(metadataArg.value == expectedHex)
        #expect(trustedArg.value  == expectedHex)
    }
}

// MARK: - Method name constants

/// Single source of truth for the method-name strings that
/// `MockMainRepository.callCount(_:)` / `.wasCalled(_:)` expect. These
/// match Swift's `#function` expansion exactly. Centralising them here
/// means a rename in production code that isn't reflected in the mock
/// surface will fail to compile against these constants rather than
/// silently pass (because a never-called name would report count 0).
private enum MethodName {
    static let setTrustedKey        = "setTrustedKey(_:forVault:)"
    static let setSecureKey         = "setSecureKey(_:forVault:)"
    static let setExternalKey       = "setExternalKey(_:forVault:)"
    static let preparedCachedKeys   = "preparedCachedKeys(for:)"
    static let generateMetadataKey  = "generateMetadataKey(using:)"
    static let setMetadataKey       = "setMetadataKey(_:)"
    static let prepareMetadataCache = "prepareMetadataKeyCache()"
}

// MARK: - Stubs

/// Generic reference wrapper used by tests to capture escaping-closure
/// output from a struct `@Test` method, where `self` is immutable.
private final class Ref<T> {
    var value: T
    init(_ value: T) { self.value = value }
}

private final class StubStorageInteractor: StorageInteracting {
    @MainActor func loadStore() async {}
    func initialize(completion: @escaping () -> Void) { completion() }
    func clear() {}
}
