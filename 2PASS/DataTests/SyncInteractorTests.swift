// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Testing
import Foundation
@testable import Data
import Common

@Suite struct SyncInteractorTests {

    // MARK: - Tombstone routing by kind (item vs tag sharing the same id)

    @Test func syncRoutesTagTombstoneToTag_whenItemAndTagShareID() {
        let sut = makeSUT()
        let id = UUID()
        let vaultID = UUID()

        let item = makeLoginItem(id: id, vaultID: vaultID, modificationDate: .early)
        let tag = makeTag(id: id, vaultID: vaultID, modificationDate: .early)
        let tombstone = makeTombstone(id: id, vaultID: vaultID, kind: .tag, deletedAt: .late)

        let result = sut.sync(
            local: [item],
            external: [],
            localTags: [tag],
            externalTags: [],
            localDeleted: [],
            externalDeleted: [tombstone]
        )

        // The tag-kinded tombstone must delete the tag and leave the item untouched.
        #expect(result.items.contains(where: { $0.id == id }))
        #expect(!result.tags.contains(where: { $0.tagID == id }))
    }

    @Test func syncRoutesLoginTombstoneToItem_whenItemAndTagShareID() {
        let sut = makeSUT()
        let id = UUID()
        let vaultID = UUID()

        let item = makeLoginItem(id: id, vaultID: vaultID, modificationDate: .early)
        let tag = makeTag(id: id, vaultID: vaultID, modificationDate: .early)
        let tombstone = makeTombstone(id: id, vaultID: vaultID, kind: .login, deletedAt: .late)

        let result = sut.sync(
            local: [item],
            external: [],
            localTags: [tag],
            externalTags: [],
            localDeleted: [],
            externalDeleted: [tombstone]
        )

        // The login-kinded tombstone must delete the item and leave the tag untouched.
        #expect(!result.items.contains(where: { $0.id == id }))
        #expect(result.tags.contains(where: { $0.tagID == id }))
    }
}

// MARK: - Fixtures

private extension Date {
    static let early = Date(timeIntervalSince1970: 1_000)
    static let late = Date(timeIntervalSince1970: 2_000)
}

private extension SyncInteractorTests {

    func makeSUT() -> SyncInteractor {
        SyncInteractor(
            itemsInteractor: NoopItemsInteractor(),
            itemsImportInteractor: NoopItemsImportInteractor(),
            deletedItemsInteractor: NoopDeletedItemsInteractor(),
            tagInteractor: NoopTagInteractor(),
            autoFillCredentialsInteractor: NoopAutoFillCredentialsInteractor()
        )
    }

    func makeLoginItem(id: ItemID, vaultID: VaultID, modificationDate: Date, trashed: Bool = false) -> ItemData {
        let metadata = ItemMetadata(
            creationDate: modificationDate,
            modificationDate: modificationDate,
            protectionLevel: .normal,
            trashedStatus: trashed ? .yes(trashingDate: modificationDate) : .no,
            tagIds: nil
        )
        let content = LoginItemContent(
            name: "item",
            username: nil,
            password: nil,
            notes: nil,
            iconType: .domainIcon(nil),
            uris: nil
        )
        return .login(LoginItemData(id: id, vaultId: vaultID, metadata: metadata, name: "item", content: content))
    }

    func makeTag(id: ItemTagID, vaultID: VaultID, modificationDate: Date) -> ItemTagData {
        ItemTagData(tagID: id, vaultID: vaultID, name: "tag", color: .gray, position: 0, modificationDate: modificationDate)
    }

    func makeTombstone(id: DeletedItemID, vaultID: VaultID, kind: DeletedItemData.Kind, deletedAt: Date) -> DeletedItemData {
        DeletedItemData(itemID: id, vaultID: vaultID, kind: kind, deletedAt: deletedAt)
    }
}

// MARK: - No-op interactor stubs (SyncInteractor.sync does not touch them)

private final class NoopItemsInteractor: ItemsInteracting {
    var hasItems: Bool { false }
    var itemsCount: Int { 0 }

    func createItem(_ item: ItemData) throws(ItemsInteractorSaveError) {}
    func updateItem(_ item: ItemData) throws(ItemsInteractorSaveError) {}
    func updateItems(_ itemIDs: [ItemID], to protectionLevel: ItemProtectionLevel) throws(ItemsInteractorSaveError) -> [ItemData] { [] }
    func saveStorage() {}
    func listItems(
        searchPhrase: String?,
        tagId: ItemTagID?,
        vaultId: VaultID?,
        contentTypes: [ItemContentType]?,
        protectionLevel: ItemProtectionLevel?,
        sortBy: SortType,
        trashed: ItemsListOptions.TrashOptions
    ) -> [ItemData] { [] }
    func listTrashedItems() -> [ItemData] { [] }
    func listAllItems() -> [ItemData] { [] }
    func getPasswordEncryptedContents(for itemID: ItemID, checkInTrash: Bool) -> Result<String?, ItemsInteractorGetError> { .success(nil) }
    func getItem(for item: ItemID, checkInTrash: Bool) -> ItemData? { nil }
    func listEncryptedItems() -> [ItemEncryptedData] { [] }
    func getEncryptedItemEntity(itemID: ItemID) -> ItemEncryptedData? { nil }
    func createEncryptedItem(_ item: ItemEncryptedData) {}
    func updateEncryptedItem(_ item: ItemEncryptedData) {}
    func deleteItem(for itemID: ItemID) {}
    func markAsTrashed(for itemID: ItemID) {}
    func markAsTrashed(for itemIDs: [ItemID]) -> [ItemData] { [] }
    func externalMarkAsTrashed(for itemID: ItemID) {}
    func markAsNotTrashed(for itemID: ItemID) {}
    func loadTrustedKey() -> Bool { false }
    func encrypt(_ string: String, isSecureField: Bool, protectionLevel: ItemProtectionLevel) -> Data? { nil }
    func encryptData(_ data: Data, isSecureField: Bool, protectionLevel: ItemProtectionLevel) -> Data? { nil }
    func decrypt(_ data: Data, isSecureField: Bool, protectionLevel: ItemProtectionLevel) -> String? { nil }
    func decryptData(_ data: Data, isSecureField: Bool, protectionLevel: ItemProtectionLevel) -> Data? { nil }
    func decryptContent<T>(_ result: T.Type, from data: Data, protectionLevel: ItemProtectionLevel) -> T? where T: Decodable { nil }
    func getCompleteDecryptedList() -> ([RawItemData], [ItemTagData]) { ([], []) }
    func reencryptDecryptedList(
        _ list: [RawItemData],
        tags: [ItemTagData],
        completion: @escaping (Result<Void, ItemsInteractorReencryptError>) -> Void
    ) {}
    func itemFilterCounts() -> ItemFilterCounts { ItemFilterCounts(byTag: [:], byProtectionLevel: [:]) }
}

private final class NoopItemsImportInteractor: ItemsImportInteracting {
    func importItems(_ items: [ItemData], tags: [ItemTagData], completion: @escaping (Int) -> Void) {}
    func importDeleted(_ deleted: [DeletedItemData]) {}
}

private final class NoopDeletedItemsInteractor: DeletedItemsInteracting {
    func createDeletedItem(id: DeletedItemID, kind: DeletedItemData.Kind, deletedAt: Date) {}
    func createDeletedItems(_ items: [DeletedItemData]) {}
    func updateDeletedItem(id: DeletedItemID, kind: DeletedItemData.Kind, deletedAt: Date) {}
    func updateDeletedItems(_ items: [DeletedItemData]) {}
    func listDeletedItems() -> [DeletedItemData] { [] }
    func deleteDeletedItem(id: DeletedItemID) {}
}

private final class NoopTagInteractor: TagInteracting {
    func suggestedNewColor() -> ItemTagColor { .gray }
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

private final class NoopAutoFillCredentialsInteractor: AutoFillCredentialsInteracting {
    func canAddSuggestionForPassword(with level: ItemProtectionLevel) -> Bool { false }
    func addSuggestions(itemID: ItemID, username: String?, uris: [PasswordURI]?, protectionLevel: ItemProtectionLevel) async throws {}
    func replaceSuggestions(from passwordData: LoginItemData, itemID: ItemID, username: String?, uris: [PasswordURI]?, protectionLevel: ItemProtectionLevel) async throws {}
    func replaceSuggestions(for items: [LoginItemData]) async throws {}
    func removeSuggestions(for passwordData: LoginItemData) async throws {}
    func removeSuggestions(for loginData: [LoginItemData]) async throws {}
    func syncSuggestions() async throws {}
}
