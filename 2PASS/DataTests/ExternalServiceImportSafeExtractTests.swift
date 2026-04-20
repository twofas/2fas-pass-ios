// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Testing
import Foundation
import CryptoKit
import ZIPFoundation
import Common
@testable import Data

/// Exercises the `ImportContext.extract` helper added for OWASP finding M-1
/// (zip-slip + zip-bomb defenses on vendor importers).
///
/// Fixtures are built in-memory via ZIPFoundation so we can craft
/// malicious archives without shipping binary blobs in the repo.
@Suite("ExternalServiceImportInteractor.ImportContext.extract")
struct ExternalServiceImportSafeExtractTests {

    private let context = Self.makeContext()

    // MARK: - Zip-slip (path validation)

    @Test("Rejects a parent-directory (`..`) entry path")
    func rejectsParentDirectoryPath() throws {
        let archive = try Self.makeInMemoryArchive(entries: [
            ("../evil.txt", Data("x".utf8))
        ])
        let entry = try Self.requireFirstEntry(in: archive)

        #expect(throws: ExternalServiceImportError.wrongFormat) {
            _ = try context.extract(entry, from: archive)
        }
    }

    @Test("Rejects an absolute entry path")
    func rejectsAbsolutePath() throws {
        let archive = try Self.makeInMemoryArchive(entries: [
            ("/etc/passwd", Data("x".utf8))
        ])
        let entry = try Self.requireFirstEntry(in: archive)

        #expect(throws: ExternalServiceImportError.wrongFormat) {
            _ = try context.extract(entry, from: archive)
        }
    }

    @Test("Rejects an embedded `..` segment in an otherwise-relative path")
    func rejectsEmbeddedParentSegment() throws {
        let archive = try Self.makeInMemoryArchive(entries: [
            ("vault/../../escape.csv", Data("x".utf8))
        ])
        let entry = try Self.requireFirstEntry(in: archive)

        #expect(throws: ExternalServiceImportError.wrongFormat) {
            _ = try context.extract(entry, from: archive)
        }
    }

    // MARK: - Zip-bomb (size cap)

    @Test("Aborts extraction when bytes exceed `maxBytes`")
    func rejectsOversizedEntry() throws {
        let payload = Data(repeating: 0x41, count: 10 * 1024) // 10 KB
        let archive = try Self.makeInMemoryArchive(entries: [
            ("data.bin", payload)
        ])
        let entry = try Self.requireFirstEntry(in: archive)

        #expect(throws: ExternalServiceImportError.wrongFileSize) {
            _ = try context.extract(entry, from: archive, maxBytes: 1024) // 1 KB cap
        }
    }

    @Test("Respects a larger explicit `maxBytes` override")
    func acceptsUpToLargerCap() throws {
        let payload = Data(repeating: 0x42, count: 64 * 1024) // 64 KB
        let archive = try Self.makeInMemoryArchive(entries: [
            ("export.data", payload)
        ])
        let entry = try Self.requireFirstEntry(in: archive)

        let extracted = try context.extract(
            entry,
            from: archive,
            maxBytes: 128 * 1024
        )
        #expect(extracted == payload)
    }

    // MARK: - Benign / control

    @Test("Returns the full payload for a well-formed top-level entry")
    func acceptsFlatPath() throws {
        let expected = Data("hello world".utf8)
        let archive = try Self.makeInMemoryArchive(entries: [
            ("data.txt", expected)
        ])
        let entry = try Self.requireFirstEntry(in: archive)

        let extracted = try context.extract(entry, from: archive)
        #expect(extracted == expected)
    }

    @Test("Accepts nested paths that don't contain traversal segments")
    func acceptsNestedPath() throws {
        let expected = Data("nested payload".utf8)
        let archive = try Self.makeInMemoryArchive(entries: [
            ("vault/subdir/file.txt", expected)
        ])
        let entry = try #require(archive.first(where: { $0.path == "vault/subdir/file.txt" }))

        let extracted = try context.extract(entry, from: archive)
        #expect(extracted == expected)
    }

    // MARK: - Integration: Apple Passwords importer rejects a zip-slip archive

    @Test("ApplePasswordsMobile importer rejects a zip-slip archive gracefully")
    func applePasswordsImporterRejectsZipSlip() async throws {
        let mockMainRepository = MockMainRepository()
        let mockURIInteractor = MockURIInteractor()
        let mockPaymentCardUtilityInteractor = MockPaymentCardUtilityInteractor()

        let vaultID = UUID()
        let keyData = Data(repeating: 0x42, count: 32)
        mockMainRepository
            .withSelectedVault(VaultEncryptedData(
                vaultID: vaultID,
                name: "Test Vault",
                trustedKey: Data(),
                createdAt: Date(),
                updatedAt: Date(),
                isEmpty: false
            ))
            .withGetKey { _, _ in SymmetricKey(data: keyData) }

        let interactor: ExternalServiceImportInteracting = ExternalServiceImportInteractor(
            mainRepository: mockMainRepository,
            uriInteractor: mockURIInteractor,
            paymentCardUtilityInteractor: mockPaymentCardUtilityInteractor
        )

        // Apple Mobile archives are located by CSV suffix — include a single
        // CSV entry whose path escapes the archive root.
        let csv = Data("Title,URL,Username,Password,Notes\nEvil,https://e,u,p,n\n".utf8)
        let archiveBytes = try Self.makeInMemoryArchiveData(entries: [
            ("../escape.csv", csv)
        ])

        await #expect(throws: ExternalServiceImportError.wrongFormat) {
            _ = try await interactor.importService(.applePasswordsMobile, content: .file(archiveBytes))
        }
    }

    // MARK: - Context factory

    private static func makeContext() -> ExternalServiceImportInteractor.ImportContext {
        ExternalServiceImportInteractor.ImportContext(
            mainRepository: MockMainRepository(),
            uriInteractor: MockURIInteractor(),
            paymentCardUtilityInteractor: MockPaymentCardUtilityInteractor()
        )
    }

    // MARK: - In-memory archive helpers

    private static func makeInMemoryArchive(
        entries: [(path: String, data: Data)]
    ) throws -> Archive {
        let bytes = try makeInMemoryArchiveData(entries: entries)
        return try Archive(data: bytes, accessMode: .read, pathEncoding: .utf8)
    }

    private static func makeInMemoryArchiveData(
        entries: [(path: String, data: Data)]
    ) throws -> Data {
        let archive = try Archive(data: Data(), accessMode: .create)
        for (path, data) in entries {
            try archive.addEntry(
                with: path,
                type: .file,
                uncompressedSize: Int64(data.count),
                provider: { offset, size in
                    let start = Int(offset)
                    let end = min(start + size, data.count)
                    return data.subdata(in: start..<end)
                }
            )
        }
        guard let serialized = archive.data else {
            throw TestError.resourceNotFound("archive.data (in-memory build)")
        }
        return serialized
    }

    private static func requireFirstEntry(in archive: Archive) throws -> Entry {
        try #require(archive.first(where: { _ in true }))
    }
}
