// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Testing
import Foundation
@testable import Data
import Common
import Storage

@Suite struct MigrationInteractorTests {

    @Test func migrateIfNeeded_runsLegacyMigration_whenLastKnownVersionIsBelow1_9_0() {
        let repo = MockMainRepository()
            .withCurrentAppVersion("1.9.0")
            .withLastKnownAppVersion("1.8.0")
        let interactor = MigrationInteractor(mainRepository: repo, tagInteractor: NoopTagInteractor())

        interactor.migrateIfNeeded()

        #expect(repo.migrateLegacyBackupConfigsCallCount == 1)
    }

    @Test func migrateIfNeeded_skipsLegacyMigration_whenLastKnownVersionIsAtLeast1_9_0() {
        let repo = MockMainRepository()
            .withCurrentAppVersion("1.9.0")
            .withLastKnownAppVersion("1.9.0")
        let interactor = MigrationInteractor(mainRepository: repo, tagInteractor: NoopTagInteractor())

        interactor.migrateIfNeeded()

        #expect(repo.migrateLegacyBackupConfigsCallCount == 0)
    }

    @Test func migrateIfNeeded_skipsLegacyMigration_onFreshInstall() {
        let repo = MockMainRepository()
            .withCurrentAppVersion("1.9.0")
            .withLastKnownAppVersion(nil)
        let interactor = MigrationInteractor(mainRepository: repo, tagInteractor: NoopTagInteractor())

        interactor.migrateIfNeeded()

        #expect(repo.migrateLegacyBackupConfigsCallCount == 0)
    }

    @Test func migrateStorageIfNeeded_backfillsEveryVault_whenLastKnownVersionIsBelow1_9_0() {
        let vault1 = Self.makeVault()
        let vault2 = Self.makeVault()
        let repo = MockMainRepository()
            .withCurrentAppVersion("1.9.0")
            .withLastKnownAppVersion("1.8.0")
            .withListEncryptedVaults { [vault1, vault2] }
        let interactor = MigrationInteractor(mainRepository: repo, tagInteractor: NoopTagInteractor())

        interactor.migrateStorageIfNeeded()

        #expect(repo.backfillVaultContentModificationDateVaultIDs == [vault1.vaultID, vault2.vaultID])
    }

    @Test func migrateStorageIfNeeded_skipsBackfill_whenLastKnownVersionIsAtLeast1_9_0() {
        let repo = MockMainRepository()
            .withCurrentAppVersion("1.9.0")
            .withLastKnownAppVersion("1.9.0")
            .withListEncryptedVaults { [Self.makeVault()] }
        let interactor = MigrationInteractor(mainRepository: repo, tagInteractor: NoopTagInteractor())

        interactor.migrateStorageIfNeeded()

        #expect(repo.backfillVaultContentModificationDateVaultIDs.isEmpty)
    }

    @Test func migrateStorageIfNeeded_skipsBackfill_onFreshInstall() {
        let repo = MockMainRepository()
            .withCurrentAppVersion("1.9.0")
            .withLastKnownAppVersion(nil)
            .withListEncryptedVaults { [Self.makeVault()] }
        let interactor = MigrationInteractor(mainRepository: repo, tagInteractor: NoopTagInteractor())

        interactor.migrateStorageIfNeeded()

        #expect(repo.backfillVaultContentModificationDateVaultIDs.isEmpty)
    }

    @Test func migrateStorageIfNeeded_isNoOp_whenVaultListIsEmpty() {
        let repo = MockMainRepository()
            .withCurrentAppVersion("1.9.0")
            .withLastKnownAppVersion("1.8.0")
            .withListEncryptedVaults { [] }
        let interactor = MigrationInteractor(mainRepository: repo, tagInteractor: NoopTagInteractor())

        interactor.migrateStorageIfNeeded()

        #expect(repo.backfillVaultContentModificationDateVaultIDs.isEmpty)
    }

    private static func makeVault(vaultID: VaultID = UUID()) -> VaultEncryptedData {
        VaultEncryptedData(
            vaultID: vaultID,
            name: "MockVault",
            trustedKey: Data(),
            createdAt: Date(),
            updatedAt: Date(),
            isEmpty: false
        )
    }
}

private final class NoopTagInteractor: TagInteracting {
    func suggestedNewColor() -> ItemTagColor { fatalError("not used in MigrationInteractorTests") }
    func createTag(name: String, color: ItemTagColor) {}
    func createTag(data: ItemTagData) {}
    func updateTag(data: ItemTagData) {}
    func deleteTag(tagID: ItemTagID) {}
    func externalDeleteTag(tagID: ItemTagID) {}
    func listAllTags() -> [ItemTagData] { [] }
    func listAllEncryptedTags() -> [ItemTagEncryptedData] { [] }
    func listTags(for vaultID: VaultID) -> [ItemTagData] { [] }
    func getTag(for id: ItemTagID) -> ItemTagData? { nil }
    func getTags(by tagIDs: [ItemTagID]) -> [ItemTagData] { [] }
    func listTagWith(_ phrase: String) -> [ItemTagData] { [] }
    func batchUpdateTagsForNewEncryption(_ tags: [ItemTagData]) {}
    func applyTagChangesToItems(_ itemIDs: [ItemID], tagsToAdd: Set<ItemTagID>, tagsToRemove: Set<ItemTagID>) {}
    func removeDuplicatedEncryptedTags() {}
    func migrateTagColors() {}
    func shouldMigrateColor(_ color: ItemTagColor) -> Bool { false }
    func saveStorage() {}
}
