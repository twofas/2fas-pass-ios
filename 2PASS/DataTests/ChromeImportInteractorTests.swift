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

@Suite("Import Chrome file")
struct ChromeImportInteractorTests {
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
    func importChromeFile() async throws {
        // GIVEN
        let data = try loadChromeTestData()

        // WHEN
        let result = try await interactor.importService(.chrome, content: .file(data))

        // THEN
        // The Chrome.csv file contains 1 login
        #expect(result.items.count == 1)
        #expect(result.tags.isEmpty)
        #expect(result.itemsConvertedToSecureNotes == 0)

        // Verify item types
        let logins = result.items.filter { if case .login = $0 { return true } else { return false } }
        #expect(logins.count == 1)
    }

    // MARK: - Login Import Tests

    @Test
    func importLoginItemFromChromeFile() async throws {
        // GIVEN
        let data = try loadChromeTestData()

        // WHEN
        let result = try await interactor.importService(.chrome, content: .file(data))

        // THEN
        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let testLogin = try #require(logins.first)
        #expect(testLogin.name == "www.youtube.com")
        #expect(testLogin.content.username == "Jeff")

        let password = try #require(decrypt(testLogin.content.password))
        #expect(password == "2asdfop3keo3jrnfdknke")

        #expect(testLogin.content.uris?.first?.uri == "https://www.youtube.com/")
        #expect(testLogin.content.uris?.first?.match == .domain)

        // Notes should contain the note from Chrome
        #expect(testLogin.content.notes == "Notatka do Chrome")
    }

    @Test
    func importLoginWithCorrectVaultAndProtectionLevel() async throws {
        // GIVEN
        let data = try loadChromeTestData()

        // WHEN
        let result = try await interactor.importService(.chrome, content: .file(data))

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

    // MARK: - Comprehensive Import Test

    @Test
    func importAllValuesFromChromeFile() async throws {
        // GIVEN - Use real implementations
        let realURIInteractor = URIInteractor(mainRepository: mockMainRepository)
        let realInteractor = ExternalServiceImportInteractor(
            mainRepository: mockMainRepository,
            uriInteractor: realURIInteractor,
            paymentCardUtilityInteractor: mockPaymentCardUtilityInteractor
        )

        let data = try loadChromeTestData()

        // WHEN
        let result = try await realInteractor.importService(.chrome, content: .file(data))

        // THEN - Verify result summary
        #expect(result.items.count == 1)
        #expect(result.tags.isEmpty)
        #expect(result.itemsConvertedToSecureNotes == 0)

        // Extract login
        let logins = result.items.compactMap { if case .login(let l) = $0 { return l } else { return nil } }
        #expect(logins.count == 1)

        // MARK: Login - "www.youtube.com"
        let loginItem = try #require(logins.first)
        #expect(loginItem.name == "www.youtube.com")
        #expect(loginItem.vaultId == testVaultID)
        #expect(loginItem.content.username == "Jeff")

        let loginPassword = try #require(decrypt(loginItem.content.password))
        #expect(loginPassword == "2asdfop3keo3jrnfdknke")

        #expect(loginItem.content.uris?[0].uri == "https://www.youtube.com/")
        #expect(loginItem.content.uris?[0].match == .domain)
        #expect(loginItem.content.notes == "Notatka do Chrome")
        #expect(loginItem.metadata.protectionLevel == .normal)
        #expect(loginItem.metadata.trashedStatus == .no)
        #expect(loginItem.metadata.tagIds == nil)
        #expect(loginItem.metadata.creationDate == Date.importPasswordPlaceholder)
        #expect(loginItem.metadata.modificationDate == Date.importPasswordPlaceholder)
    }

    // MARK: - Unknown Headers Test

    @Test
    func importLoginWithUnknownHeaders() async throws {
        // GIVEN - CSV with unknown/future headers
        let csvData = """
            name,url,username,password,note,future_field,another_new_column
            "www.example.com","https://www.example.com/","testuser","testpass123","My note","future value","new data"
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.chrome, content: .file(csvData))

        // THEN
        #expect(result.items.count == 1)

        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let testLogin = try #require(logins.first)
        #expect(testLogin.name == "www.example.com")
        #expect(testLogin.content.username == "testuser")

        let password = try #require(decrypt(testLogin.content.password))
        #expect(password == "testpass123")

        // Notes should contain original note plus unknown headers as additional info
        let notes = try #require(testLogin.content.notes)
        #expect(notes.contains("My note"))
        #expect(notes.contains("Another new column: new data"))
        #expect(notes.contains("Future field: future value"))
    }

    @Test
    func importLoginWithUnknownHeadersNoOriginalNote() async throws {
        // GIVEN - CSV with unknown headers but no original note
        let csvData = """
            name,url,username,password,note,custom_data
            "www.example.com","https://www.example.com/","testuser","testpass123","","some custom value"
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.chrome, content: .file(csvData))

        // THEN
        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let testLogin = try #require(logins.first)
        // Notes should only contain the unknown header info
        #expect(testLogin.content.notes == "Custom data: some custom value")
    }

    // MARK: - Error Handling Tests

    @Test
    func invalidCSVThrowsWrongFormat() async {
        // GIVEN
        let invalidData = "not,valid,csv,without,proper,headers".data(using: .utf8)!

        // WHEN/THEN
        await #expect(throws: ExternalServiceImportError.wrongFormat) {
            try await interactor.importService(.chrome, content: .file(invalidData))
        }
    }

    @Test
    func missingVaultThrowsWrongFormat() async throws {
        // GIVEN
        mockMainRepository.withSelectedVault(nil)
        let data = try loadChromeTestData()

        // WHEN/THEN
        await #expect(throws: ExternalServiceImportError.wrongFormat) {
            try await interactor.importService(.chrome, content: .file(data))
        }
    }

    @Test
    func emptyCSVWithHeadersReturnsEmptyResult() async throws {
        // GIVEN
        let csvData = "name,url,username,password,note\n".data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.chrome, content: .file(csvData))

        // THEN
        #expect(result.items.isEmpty)
        #expect(result.tags.isEmpty)
        #expect(result.itemsConvertedToSecureNotes == 0)
    }

    @Test
    func csvWithEmptyRowsSkipsEmptyRows() async throws {
        // GIVEN
        let csvData = """
            name,url,username,password,note
            "www.example.com","https://example.com","user1","pass1","note1"
            "","","","",""
            "www.example2.com","https://example2.com","user2","pass2","note2"
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.chrome, content: .file(csvData))

        // THEN
        #expect(result.items.count == 2)
    }

    @Test
    func importMultipleLogins() async throws {
        // GIVEN
        let csvData = """
            name,url,username,password,note
            "github.com","https://github.com","developer","secretpass123","Work account"
            "gitlab.com","https://gitlab.com","dev@company.com","anotherpass","Personal"
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.chrome, content: .file(csvData))

        // THEN
        #expect(result.items.count == 2)

        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let githubLogin = logins.first { $0.name == "github.com" }
        #expect(githubLogin?.content.username == "developer")
        let githubPassword = decrypt(githubLogin?.content.password)
        #expect(githubPassword == "secretpass123")
        #expect(githubLogin?.content.notes == "Work account")

        let gitlabLogin = logins.first { $0.name == "gitlab.com" }
        #expect(gitlabLogin?.content.username == "dev@company.com")
        let gitlabPassword = decrypt(gitlabLogin?.content.password)
        #expect(gitlabPassword == "anotherpass")
        #expect(gitlabLogin?.content.notes == "Personal")
    }

    @Test
    func importLoginWithMissingOptionalFields() async throws {
        // GIVEN - CSV with missing optional fields (empty note)
        let csvData = """
            name,url,username,password,note
            "test.com","https://test.com","testuser","testpass",""
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.chrome, content: .file(csvData))

        // THEN
        #expect(result.items.count == 1)

        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let testLogin = try #require(logins.first)
        #expect(testLogin.name == "test.com")
        #expect(testLogin.content.username == "testuser")

        let password = try #require(decrypt(testLogin.content.password))
        #expect(password == "testpass")

        // No notes
        #expect(testLogin.content.notes == nil)
    }

    @Test
    func importLoginWithEmptyPassword() async throws {
        // GIVEN - CSV with empty password
        let csvData = """
            name,url,username,password,note
            "test.com","https://test.com","testuser","","Note"
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.chrome, content: .file(csvData))

        // THEN
        #expect(result.items.count == 1)

        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let testLogin = try #require(logins.first)
        #expect(testLogin.content.password == nil)
    }

    // MARK: - Helper Methods

    private func loadChromeTestData() throws -> Data {
        guard let url = Bundle(for: MockMainRepository.self).url(forResource: "Chrome", withExtension: "csv") else {
            throw TestError.resourceNotFound("Chrome.csv test resource not found")
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

private enum TestError: Error {
    case resourceNotFound(String)
}
