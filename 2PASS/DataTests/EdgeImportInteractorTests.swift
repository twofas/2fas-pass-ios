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

@Suite("Import Edge file")
struct EdgeImportInteractorTests {
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
    func importEdgeFile() async throws {
        // GIVEN
        let data = try loadEdgeTestData()

        // WHEN
        let result = try await interactor.importService(.microsoftEdge, content: .file(data))

        // THEN
        // The Edge.csv file contains 2 logins
        #expect(result.items.count == 2)
        #expect(result.tags.isEmpty)
        #expect(result.itemsConvertedToSecureNotes == 0)

        // Verify item types
        let logins = result.items.filter { if case .login = $0 { return true } else { return false } }
        #expect(logins.count == 2)
    }

    // MARK: - Login Import Tests

    @Test
    func importLoginItemFromEdgeFile() async throws {
        // GIVEN
        let data = try loadEdgeTestData()

        // WHEN
        let result = try await interactor.importService(.microsoftEdge, content: .file(data))

        // THEN
        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let amazonLogin = try #require(logins.first { $0.name == "www.amazon.pl" })
        #expect(amazonLogin.content.username == "Erunestian")

        let password = try #require(decrypt(amazonLogin.content.password))
        #expect(password == "12312312rfdsf")

        #expect(amazonLogin.content.uris?.first?.uri == "https://www.amazon.pl/")
        #expect(amazonLogin.content.uris?.first?.match == .domain)

        // Notes should contain the note from Edge
        #expect(amazonLogin.content.notes == "Hasło 2")
    }

    @Test
    func importSecondLoginFromEdgeFile() async throws {
        // GIVEN
        let data = try loadEdgeTestData()

        // WHEN
        let result = try await interactor.importService(.microsoftEdge, content: .file(data))

        // THEN
        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let youtubeLogin = try #require(logins.first { $0.name == "www.youtube.com" })
        #expect(youtubeLogin.content.username == "Arthur Morgan")

        let password = try #require(decrypt(youtubeLogin.content.password))
        #expect(password == "123124123123123")

        #expect(youtubeLogin.content.uris?.first?.uri == "https://www.youtube.com/")
        #expect(youtubeLogin.content.notes == "Notka do edge")
    }

    @Test
    func importLoginWithCorrectVaultAndProtectionLevel() async throws {
        // GIVEN
        let data = try loadEdgeTestData()

        // WHEN
        let result = try await interactor.importService(.microsoftEdge, content: .file(data))

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
    func importAllValuesFromEdgeFile() async throws {
        // GIVEN - Use real implementations
        let realURIInteractor = URIInteractor(mainRepository: mockMainRepository)
        let realInteractor = ExternalServiceImportInteractor(
            mainRepository: mockMainRepository,
            uriInteractor: realURIInteractor,
            paymentCardUtilityInteractor: mockPaymentCardUtilityInteractor
        )

        let data = try loadEdgeTestData()

        // WHEN
        let result = try await realInteractor.importService(.microsoftEdge, content: .file(data))

        // THEN - Verify result summary
        #expect(result.items.count == 2)
        #expect(result.tags.isEmpty)
        #expect(result.itemsConvertedToSecureNotes == 0)

        // Extract logins
        let logins = result.items.compactMap { if case .login(let l) = $0 { return l } else { return nil } }
        #expect(logins.count == 2)

        // MARK: Login - "www.amazon.pl"
        let amazonLogin = try #require(logins.first { $0.name == "www.amazon.pl" })
        #expect(amazonLogin.vaultId == testVaultID)
        #expect(amazonLogin.content.username == "Erunestian")

        let amazonPassword = try #require(decrypt(amazonLogin.content.password))
        #expect(amazonPassword == "12312312rfdsf")

        #expect(amazonLogin.content.uris?[0].uri == "https://www.amazon.pl/")
        #expect(amazonLogin.content.uris?[0].match == .domain)
        #expect(amazonLogin.content.notes == "Hasło 2")
        #expect(amazonLogin.metadata.protectionLevel == .normal)
        #expect(amazonLogin.metadata.trashedStatus == .no)
        #expect(amazonLogin.metadata.tagIds == nil)
        #expect(amazonLogin.metadata.creationDate == Date.importPasswordPlaceholder)
        #expect(amazonLogin.metadata.modificationDate == Date.importPasswordPlaceholder)

        // MARK: Login - "www.youtube.com"
        let youtubeLogin = try #require(logins.first { $0.name == "www.youtube.com" })
        #expect(youtubeLogin.content.username == "Arthur Morgan")

        let youtubePassword = try #require(decrypt(youtubeLogin.content.password))
        #expect(youtubePassword == "123124123123123")

        #expect(youtubeLogin.content.uris?[0].uri == "https://www.youtube.com/")
        #expect(youtubeLogin.content.notes == "Notka do edge")
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
        let result = try await interactor.importService(.microsoftEdge, content: .file(csvData))

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
        let result = try await interactor.importService(.microsoftEdge, content: .file(csvData))

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
            try await interactor.importService(.microsoftEdge, content: .file(invalidData))
        }
    }

    @Test
    func missingVaultThrowsWrongFormat() async throws {
        // GIVEN
        mockMainRepository.withSelectedVault(nil)
        let data = try loadEdgeTestData()

        // WHEN/THEN
        await #expect(throws: ExternalServiceImportError.wrongFormat) {
            try await interactor.importService(.microsoftEdge, content: .file(data))
        }
    }

    @Test
    func emptyCSVWithHeadersReturnsEmptyResult() async throws {
        // GIVEN
        let csvData = "name,url,username,password,note\n".data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.microsoftEdge, content: .file(csvData))

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
        let result = try await interactor.importService(.microsoftEdge, content: .file(csvData))

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
        let result = try await interactor.importService(.microsoftEdge, content: .file(csvData))

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
        let result = try await interactor.importService(.microsoftEdge, content: .file(csvData))

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
        let result = try await interactor.importService(.microsoftEdge, content: .file(csvData))

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

    private func loadEdgeTestData() throws -> Data {
        guard let url = Bundle(for: MockMainRepository.self).url(forResource: "Edge", withExtension: "csv") else {
            throw TestError.resourceNotFound("Edge.csv test resource not found")
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
