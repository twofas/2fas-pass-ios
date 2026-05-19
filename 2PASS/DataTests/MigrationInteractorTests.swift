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
