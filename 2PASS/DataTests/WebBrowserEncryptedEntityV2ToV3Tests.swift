// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Testing
import Foundation
import CoreData
import CryptoKit
import Storage

// MigrationController.current is a global static; `.serialized` prevents
// parallel tests in this suite from racing on it.
@Suite("WebBrowser V2 → V3 migration", .serialized)
struct WebBrowserEncryptedEntityV2ToV3Tests {

    private static let storageBundle = Bundle(for: MigrationController.self)
    private static let momdSubdirectory = "ColdStorage.momd"
    private static let entityName = "WebBrowserEncryptedEntity"

    // Models and the custom mapping model are parsed once per test process, not
    // per @Test, because NSManagedObjectModel loading and NSMappingModel lookup
    // are the dominant cost of a round-trip migration test (several dozen ms).
    private static let v2Model: NSManagedObjectModel = loadModel(named: "ColdStorage2")
    private static let v3Model: NSManagedObjectModel = loadModel(named: "ColdStorage3")
    private static let mappingModel: NSMappingModel = {
        guard let mapping = NSMappingModel(
            from: [storageBundle],
            forSourceModel: v2Model,
            destinationModel: v3Model
        ) else {
            fatalError("ColdStorage2→ColdStorage3 custom mapping model not found in Storage framework bundle")
        }
        return mapping
    }()

    private enum Field: String {
        case webBrowserID
        case firstConnectionDate
        case lastConnectionDate
        case extensionName
        case name
        case publicKey
        case version
        case nextSessionId
    }

    private let testAppKey = SymmetricKey(size: .bits256)
    private let testMetadataKey = SymmetricKey(size: .bits256)

    init() {
        MigrationController.current = MigrationController(
            encrypt: { [testAppKey, testMetadataKey] data, key in
                switch key {
                case .appKey:
                    return Self.seal(data, using: testAppKey)
                case .metadataKey:
                    return Self.seal(data, using: testMetadataKey)
                case .vault:
                    // Vault keys are not exercised by WebBrowser V2→V3; a test that
                    // needs them must construct its own MigrationController.
                    return nil
                }
            },
            decrypt: { [testAppKey, testMetadataKey] data, key in
                switch key {
                case .appKey:
                    return try? Self.open(data, using: testAppKey)
                case .metadataKey:
                    return try? Self.open(data, using: testMetadataKey)
                case .vault:
                    return nil
                }
            }
        )
    }

    // MARK: - Tests

    @Test(arguments: [
        WebBrowserFixture(
            webBrowserID: UUID(),
            extensionName: "Brave Extension",
            name: "MacBook Pro",
            publicKey: "AAAA/BBBB/CCCC",
            version: "1.2.3",
            nextSessionId: "session-xyz",
            firstConnectionDate: Date(timeIntervalSince1970: 1_700_000_000),
            lastConnectionDate: Date(timeIntervalSince1970: 1_700_001_000)
        ),
        WebBrowserFixture(
            webBrowserID: UUID(),
            extensionName: "Chrome",
            name: "iMac",
            publicKey: "PK-1",
            version: "9.9.9",
            nextSessionId: nil,
            firstConnectionDate: Date(timeIntervalSince1970: 1_710_000_000),
            lastConnectionDate: Date(timeIntervalSince1970: 1_710_001_000)
        )
    ])
    func singleRowMigrates(fixture: WebBrowserFixture) throws {
        defer { MigrationController.current = nil }

        let tempDir = Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let destURL = try runMigration(tempDir: tempDir, fixtures: [fixture])

        let rows = try readRows(at: destURL)
        #expect(rows.count == 1)
        let row = try #require(rows.first)

        try assertRowMatchesFixture(row, fixture: fixture)
    }

    @Test
    func multipleRowsAllMigrate() throws {
        defer { MigrationController.current = nil }

        let tempDir = Self.makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: tempDir) }

        var fixtures: [WebBrowserFixture] = []
        for index in 0..<3 {
            let firstTimestamp: TimeInterval = 1_700_000_000 + Double(index) * 100
            let lastTimestamp: TimeInterval = 1_700_000_500 + Double(index) * 100
            fixtures.append(WebBrowserFixture(
                webBrowserID: UUID(),
                extensionName: "Ext\(index)",
                name: "Device \(index)",
                publicKey: "PK-\(index)",
                version: "\(index).0.0",
                nextSessionId: "session-\(index)",
                firstConnectionDate: Date(timeIntervalSince1970: firstTimestamp),
                lastConnectionDate: Date(timeIntervalSince1970: lastTimestamp)
            ))
        }

        let destURL = try runMigration(tempDir: tempDir, fixtures: fixtures)

        let rows = try readRows(at: destURL)
        #expect(rows.count == fixtures.count)

        // Group destination rows by webBrowserID so the assertion is independent
        // of fetch order — Core Data does not guarantee fetch order without a sort descriptor.
        let rowsByID = Dictionary(uniqueKeysWithValues: rows.compactMap { row -> (UUID, NSManagedObject)? in
            guard let id = row.value(forKey: Field.webBrowserID.rawValue) as? UUID else { return nil }
            return (id, row)
        })

        for fixture in fixtures {
            let row = try #require(rowsByID[fixture.webBrowserID], "Missing row for \(fixture.webBrowserID)")
            try assertRowMatchesFixture(row, fixture: fixture)
        }
    }

    // MARK: - Fixture

    struct WebBrowserFixture: Sendable {
        let webBrowserID: UUID
        let extensionName: String
        let name: String
        let publicKey: String
        let version: String
        let nextSessionId: String?
        let firstConnectionDate: Date
        let lastConnectionDate: Date
    }

    // MARK: - Migration driver

    /// Seeds a ColdStorage2 source store with `fixtures`, runs `NSMigrationManager`
    /// with the custom mapping model from the Storage framework bundle, and returns
    /// the destination store URL.
    private func runMigration(tempDir: URL, fixtures: [WebBrowserFixture]) throws -> URL {
        let sourceURL = tempDir.appendingPathComponent("source.sqlite")
        let destURL = tempDir.appendingPathComponent("dest.sqlite")

        try seedSourceStore(at: sourceURL, fixtures: fixtures)

        let manager = NSMigrationManager(sourceModel: Self.v2Model, destinationModel: Self.v3Model)
        try manager.migrateStore(
            from: sourceURL,
            sourceType: NSSQLiteStoreType,
            options: nil,
            with: Self.mappingModel,
            toDestinationURL: destURL,
            destinationType: NSSQLiteStoreType,
            destinationOptions: nil
        )

        return destURL
    }

    private func seedSourceStore(at url: URL, fixtures: [WebBrowserFixture]) throws {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: Self.v2Model)
        // DELETE journal mode avoids WAL sidecar flush issues between the seed
        // phase and the migration — writes go straight to the main .sqlite file.
        let options: [String: Any] = [NSSQLitePragmasOption: ["journal_mode": "DELETE"]]
        _ = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: url,
            options: options
        )

        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        for fixture in fixtures {
            let row = NSEntityDescription.insertNewObject(forEntityName: Self.entityName, into: context)
            row.setValue(fixture.webBrowserID, forKey: Field.webBrowserID.rawValue)
            row.setValue(fixture.firstConnectionDate, forKey: Field.firstConnectionDate.rawValue)
            row.setValue(fixture.lastConnectionDate, forKey: Field.lastConnectionDate.rawValue)
            row.setValue(try sealedWithAppKey(fixture.extensionName), forKey: Field.extensionName.rawValue)
            row.setValue(try sealedWithAppKey(fixture.name), forKey: Field.name.rawValue)
            row.setValue(try sealedWithAppKey(fixture.publicKey), forKey: Field.publicKey.rawValue)
            row.setValue(try sealedWithAppKey(fixture.version), forKey: Field.version.rawValue)
            if let sessionId = fixture.nextSessionId {
                row.setValue(try sealedWithAppKey(sessionId), forKey: Field.nextSessionId.rawValue)
            }
        }

        try context.save()

        // Close the store so NSMigrationManager can open it cleanly.
        for store in coordinator.persistentStores {
            try coordinator.remove(store)
        }
    }

    private func readRows(at url: URL) throws -> [NSManagedObject] {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: Self.v3Model)
        _ = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: url,
            options: nil
        )

        let context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        context.persistentStoreCoordinator = coordinator

        let request = NSFetchRequest<NSManagedObject>(entityName: Self.entityName)
        return try context.fetch(request)
    }

    // MARK: - Assertions

    private func assertRowMatchesFixture(_ row: NSManagedObject, fixture: WebBrowserFixture) throws {
        // Pass-through fields copied by the inferred attribute mappings.
        #expect(row.value(forKey: Field.webBrowserID.rawValue) as? UUID == fixture.webBrowserID)
        #expect(row.value(forKey: Field.firstConnectionDate.rawValue) as? Date == fixture.firstConnectionDate)
        #expect(row.value(forKey: Field.lastConnectionDate.rawValue) as? Date == fixture.lastConnectionDate)

        // Ciphertext fields re-encrypted with the metadata key by the policy.
        #expect(try openedWithMetadataKey(row, field: .extensionName) == fixture.extensionName)
        #expect(try openedWithMetadataKey(row, field: .name) == fixture.name)
        #expect(try openedWithMetadataKey(row, field: .publicKey) == fixture.publicKey)
        #expect(try openedWithMetadataKey(row, field: .version) == fixture.version)

        if let expectedSessionId = fixture.nextSessionId {
            #expect(try openedWithMetadataKey(row, field: .nextSessionId) == expectedSessionId)
        } else {
            #expect(row.value(forKey: Field.nextSessionId.rawValue) == nil)
        }
    }

    // MARK: - Crypto helpers

    private func sealedWithAppKey(_ plaintext: String) throws -> Data {
        let plaintextData = try #require(plaintext.data(using: .utf8))
        return try #require(Self.seal(plaintextData, using: testAppKey))
    }

    private func openedWithMetadataKey(_ row: NSManagedObject, field: Field) throws -> String {
        let cipher = try #require(row.value(forKey: field.rawValue) as? Data, "Missing ciphertext for \(field.rawValue)")
        let plaintext = try Self.open(cipher, using: testMetadataKey)
        return try #require(String(data: plaintext, encoding: .utf8))
    }

    private static func seal(_ plaintext: Data, using key: SymmetricKey) -> Data? {
        guard let sealed = try? AES.GCM.seal(plaintext, using: key) else { return nil }
        return sealed.combined
    }

    private static func open(_ combined: Data, using key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(box, using: key)
    }

    // MARK: - Model loading

    private static func loadModel(named name: String) -> NSManagedObjectModel {
        guard let url = storageBundle.url(
            forResource: name,
            withExtension: "mom",
            subdirectory: momdSubdirectory
        ) else {
            fatalError("Model '\(name)' not found in Storage framework bundle")
        }
        guard let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("Failed to load model '\(name)' from Storage framework bundle")
        }
        return model
    }

    // MARK: - Temp directory

    private static func makeTempDirectory() -> URL {
        let url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("WebBrowserMigrationTest-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
