// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Testing
import Foundation
import Common
import CryptoKit
@testable import Data

@Suite("Import KeePass file")
struct KeePassImportInteractorTests {
    private let mockMainRepository: MockMainRepository
    private let mockURIInteractor: MockURIInteractor
    private let mockPaymentCardUtilityInteractor: MockPaymentCardUtilityInteractor
    private let interactor: ExternalServiceImportInteracting
    private let testVaultID = UUID()

    init() {
        mockMainRepository = MockMainRepository()
        mockURIInteractor = MockURIInteractor()
        mockPaymentCardUtilityInteractor = MockPaymentCardUtilityInteractor()

        // Set up vault and encryption key
        let keyData = Data(repeating: 0x42, count: 32)
        mockMainRepository
            .withSelectedVault(VaultEncryptedData(
                vaultID: testVaultID,
                name: "Test Vault",
                trustedKey: Data(),
                createdAt: Date(),
                updatedAt: Date(),
                isEmpty: false
            ))
            .withGetKey { _, _ in SymmetricKey(data: keyData) }

        interactor = ExternalServiceImportInteractor(
            mainRepository: mockMainRepository,
            uriInteractor: mockURIInteractor,
            paymentCardUtilityInteractor: mockPaymentCardUtilityInteractor
        )
    }

    // MARK: - Full Import Test

    @Test
    func importKeePassFile() async throws {
        // GIVEN
        let data = try loadKeePassTestData()

        // WHEN
        let result = try await interactor.importService(.keePass, content: .file(data))

        // THEN
        #expect(result.items.count == 4)
        #expect(result.tags.isEmpty)
        #expect(result.itemsConvertedToSecureNotes == 0)

        // Verify item types
        let logins = result.items.filter { if case .login = $0 { return true } else { return false } }
        #expect(logins.count == 4)
    }

    // MARK: - Unknown Headers Test (Critical)

    @Test
    func importLoginWithUnknownHeaders() async throws {
        // GIVEN - CSV with unknown columns (from test data row 5: "Entry with extras")
        let csvData = """
            "Account","Login Name","Password","Web Site","Comments","Custom Field","Another Extra"
            "Entry with extras","extrauser","extrapass123","https://example.com/","Original note","Custom value here","Extra data"
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.keePass, content: .file(csvData))

        // THEN
        #expect(result.items.count == 1)

        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let testLogin = try #require(logins.first)
        #expect(testLogin.name == "Entry with extras")
        #expect(testLogin.content.username == "extrauser")

        let password = try #require(decrypt(testLogin.content.password))
        #expect(password == "extrapass123")

        // Notes should contain original note plus unknown headers as additional info (exact match)
        let expectedNotes = """
        Original note

        Another Extra: Extra data
        Custom Field: Custom value here
        """
        #expect(testLogin.content.notes == expectedNotes)
    }

    @Test
    func importLoginWithUnknownHeadersNoOriginalNote() async throws {
        // GIVEN - CSV with unknown headers but no original note
        let csvData = """
            "Account","Login Name","Password","Web Site","Comments","Custom Field"
            "Test Entry","testuser","testpass123","https://test.com/","","Custom data value"
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.keePass, content: .file(csvData))

        // THEN
        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let testLogin = try #require(logins.first)
        // Notes should only contain the unknown header info
        #expect(testLogin.content.notes == "Custom Field: Custom data value")
    }

    // MARK: - Standard Entry Tests

    @Test
    func importStandardEntry() async throws {
        // GIVEN - CSV with only standard columns (no unknown headers)
        let csvData = """
            "Account","Login Name","Password","Web Site","Comments"
            "Sample Entry","User Name","Password","https://keepass.info/","Notes"
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.keePass, content: .file(csvData))

        // THEN
        #expect(result.items.count == 1)

        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let testLogin = try #require(logins.first)
        #expect(testLogin.name == "Sample Entry")
        #expect(testLogin.content.username == "User Name")

        let password = try #require(decrypt(testLogin.content.password))
        #expect(password == "Password")

        #expect(testLogin.content.uris?.first?.uri == "https://keepass.info/")
        #expect(testLogin.content.uris?.first?.match == .domain)
        #expect(testLogin.content.notes == "Notes")
    }

    @Test
    func importLoginWithCorrectVaultAndProtectionLevel() async throws {
        // GIVEN
        let data = try loadKeePassTestData()

        // WHEN
        let result = try await interactor.importService(.keePass, content: .file(data))

        // THEN
        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let testLogin = try #require(logins.first)
        #expect(testLogin.vaultId == testVaultID)
        #expect(testLogin.metadata.protectionLevel == .normal)
        #expect(testLogin.metadata.trashedStatus == .no)
        #expect(testLogin.metadata.tagIds == nil)
    }

    // MARK: - Error Handling Tests

    @Test
    func invalidCSVThrowsWrongFormat() async {
        // GIVEN
        let invalidData = "not,valid,csv,without,proper,headers".data(using: .utf8)!

        // WHEN/THEN
        await #expect(throws: ExternalServiceImportError.wrongFormat) {
            try await interactor.importService(.keePass, content: .file(invalidData))
        }
    }

    @Test
    func missingVaultThrowsWrongFormat() async throws {
        // GIVEN
        mockMainRepository.withSelectedVault(nil)
        let data = try loadKeePassTestData()

        // WHEN/THEN
        await #expect(throws: ExternalServiceImportError.wrongFormat) {
            try await interactor.importService(.keePass, content: .file(data))
        }
    }

    @Test
    func emptyCSVWithHeadersReturnsEmptyResult() async throws {
        // GIVEN
        let csvData = "\"Account\",\"Login Name\",\"Password\",\"Web Site\",\"Comments\"\n".data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.keePass, content: .file(csvData))

        // THEN
        #expect(result.items.isEmpty)
        #expect(result.tags.isEmpty)
        #expect(result.itemsConvertedToSecureNotes == 0)
    }

    @Test
    func csvWithEmptyRowsSkipsEmptyRows() async throws {
        // GIVEN
        let csvData = """
            "Account","Login Name","Password","Web Site","Comments"
            "Entry1","user1","pass1","https://example1.com","note1"
            "","","","",""
            "Entry2","user2","pass2","https://example2.com","note2"
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.keePass, content: .file(csvData))

        // THEN
        #expect(result.items.count == 2)
    }

    @Test
    func importMultipleLogins() async throws {
        // GIVEN
        let csvData = """
            "Account","Login Name","Password","Web Site","Comments"
            "GitHub","developer","secretpass123","https://github.com","Work account"
            "Gmail","personal@gmail.com","gmailpass456","https://gmail.com","Personal email"
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.keePass, content: .file(csvData))

        // THEN
        #expect(result.items.count == 2)

        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let githubLogin = logins.first { $0.name == "GitHub" }
        #expect(githubLogin?.content.username == "developer")
        let githubPassword = decrypt(githubLogin?.content.password)
        #expect(githubPassword == "secretpass123")
        #expect(githubLogin?.content.notes == "Work account")

        let gmailLogin = logins.first { $0.name == "Gmail" }
        #expect(gmailLogin?.content.username == "personal@gmail.com")
        let gmailPassword = decrypt(gmailLogin?.content.password)
        #expect(gmailPassword == "gmailpass456")
        #expect(gmailLogin?.content.notes == "Personal email")
    }

    @Test
    func importLoginWithMissingOptionalFields() async throws {
        // GIVEN - CSV with missing optional fields (empty password and comments)
        let csvData = """
            "Account","Login Name","Password","Web Site","Comments"
            "test.com","testuser","","https://test.com",""
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.keePass, content: .file(csvData))

        // THEN
        #expect(result.items.count == 1)

        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let testLogin = try #require(logins.first)
        #expect(testLogin.name == "test.com")
        #expect(testLogin.content.username == "testuser")
        #expect(testLogin.content.password == nil)
        #expect(testLogin.content.notes == nil)
    }

    @Test
    func importLoginWithEmptyUsername() async throws {
        // GIVEN - CSV with empty username
        let csvData = """
            "Account","Login Name","Password","Web Site","Comments"
            "test.com","","testpass","https://test.com","Note"
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.keePass, content: .file(csvData))

        // THEN
        #expect(result.items.count == 1)

        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let testLogin = try #require(logins.first)
        #expect(testLogin.content.username == nil)
    }

    // MARK: - Helper Methods

    private func loadKeePassTestData() throws -> Data {
        guard let url = Bundle(for: MockMainRepository.self).url(forResource: "KeePass", withExtension: "csv") else {
            throw TestError.resourceNotFound("KeePass.csv test resource not found")
        }
        return try Data(contentsOf: url)
    }

    private func decrypt(_ data: Data?) -> String? {
        guard let data,
              let key = mockMainRepository.getKey(isPassword: true, protectionLevel: .normal),
              let decrypted = mockMainRepository.decrypt(data, key: key) else {
            return nil
        }
        return String(data: decrypted, encoding: .utf8)
    }
}

extension KeePassImportInteractorTests {

    @Suite("Import KeePass test file - comprehensive verification")
    struct IntegrationTests {

        private let mockMainRepository = MockMainRepository.defaultConfiguration()
        private let paymentCardUtilityInteractor = PaymentCardUtilityInteractor()
        private let uriInteractor: URIInteractor

        init() {
            self.uriInteractor = URIInteractor(mainRepository: mockMainRepository)
        }

        @Test
        func importKeePassCSVFile() async throws {
            let interactor = ExternalServiceImportInteractor(
                mainRepository: mockMainRepository,
                uriInteractor: uriInteractor,
                paymentCardUtilityInteractor: paymentCardUtilityInteractor
            )

            let data = try loadKeePassTestData()

            // WHEN
            let result = try await interactor.importService(.keePass, content: .file(data))

            // THEN - Verify result summary
            #expect(result.items.count == 4)
            #expect(result.tags.isEmpty) // KeePass CSV doesn't support folders/tags
            #expect(result.itemsConvertedToSecureNotes == 0)

            // Extract logins
            let logins = result.items.compactMap { if case .login(let l) = $0 { return l } else { return nil } }
            #expect(logins.count == 4)

            // MARK: Login #1 - "Sample Entry"
            let sampleEntry = try #require(logins.first { $0.name == "Sample Entry" })
            #expect(sampleEntry.vaultId == mockMainRepository.selectedVault?.vaultID)
            #expect(sampleEntry.content.username == "User Name")

            let samplePassword = try #require(decrypt(sampleEntry.content.password))
            #expect(samplePassword == "Password")

            #expect(sampleEntry.content.uris?.count == 1)
            #expect(sampleEntry.content.uris?[0].uri == "https://keepass.info/")
            #expect(sampleEntry.content.uris?[0].match == .domain)
            #expect(sampleEntry.content.notes == "Notes")
            #expect(sampleEntry.metadata.protectionLevel == .normal)
            #expect(sampleEntry.metadata.trashedStatus == .no)
            #expect(sampleEntry.metadata.tagIds == nil)
            #expect(sampleEntry.metadata.creationDate == Date.importPasswordPlaceholder)
            #expect(sampleEntry.metadata.modificationDate == Date.importPasswordPlaceholder)

            // MARK: Login #2 - "Sample Entry #2"
            let sampleEntry2 = try #require(logins.first { $0.name == "Sample Entry #2" })
            #expect(sampleEntry2.vaultId == mockMainRepository.selectedVault?.vaultID)
            #expect(sampleEntry2.content.username == "Michael321")

            let sample2Password = try #require(decrypt(sampleEntry2.content.password))
            #expect(sample2Password == "12345")

            #expect(sampleEntry2.content.uris?.count == 1)
            #expect(sampleEntry2.content.uris?[0].uri == "https://keepass.info/help/kb/testform.html")
            #expect(sampleEntry2.content.uris?[0].match == .domain)
            #expect(sampleEntry2.content.notes == nil) // Empty comments field
            #expect(sampleEntry2.metadata.protectionLevel == .normal)
            #expect(sampleEntry2.metadata.trashedStatus == .no)
            #expect(sampleEntry2.metadata.tagIds == nil)

            // MARK: Login #3 - "Login z dodatkami"
            let loginZDodatkami = try #require(logins.first { $0.name == "Login z dodatkami" })
            #expect(loginZDodatkami.vaultId == mockMainRepository.selectedVault?.vaultID)
            #expect(loginZDodatkami.content.username == "Batman")

            let loginZPassword = try #require(decrypt(loginZDodatkami.content.password))
            #expect(loginZPassword == "lwqU3RF0vyYE088f3nYS")

            #expect(loginZDodatkami.content.uris == nil) // Empty URL field
            #expect(loginZDodatkami.content.notes == "Notatki do Keepassa")
            #expect(loginZDodatkami.metadata.protectionLevel == .normal)
            #expect(loginZDodatkami.metadata.trashedStatus == .no)
            #expect(loginZDodatkami.metadata.tagIds == nil)

            // MARK: Login #4 - "Entry with extras" (CRITICAL TEST - Unknown Fields)
            let entryWithExtras = try #require(logins.first { $0.name == "Entry with extras" })
            #expect(entryWithExtras.vaultId == mockMainRepository.selectedVault?.vaultID)
            #expect(entryWithExtras.content.username == "extrauser")

            let extrasPassword = try #require(decrypt(entryWithExtras.content.password))
            #expect(extrasPassword == "extrapass123")

            #expect(entryWithExtras.content.uris?.count == 1)
            #expect(entryWithExtras.content.uris?[0].uri == "https://example.com/")
            #expect(entryWithExtras.content.uris?[0].match == .domain)

            // CRITICAL: Verify notes contain original note + unknown fields (exact match)
            let expectedNotes = """
            Original note

            Another Extra: Extra data
            Custom Field: Custom value here
            """
            #expect(entryWithExtras.content.notes == expectedNotes)

            #expect(entryWithExtras.metadata.protectionLevel == .normal)
            #expect(entryWithExtras.metadata.trashedStatus == .no)
            #expect(entryWithExtras.metadata.tagIds == nil)
        }

        private func loadKeePassTestData() throws -> Data {
            guard let url = Bundle(for: MockMainRepository.self).url(forResource: "KeePass", withExtension: "csv") else {
                throw TestError.resourceNotFound("KeePass.csv test resource not found")
            }
            return try Data(contentsOf: url)
        }

        private func decrypt(_ data: Data?) -> String? {
            DataTests.decrypt(data, using: mockMainRepository)
        }
    }
}

private enum TestError: Error {
    case resourceNotFound(String)
}
