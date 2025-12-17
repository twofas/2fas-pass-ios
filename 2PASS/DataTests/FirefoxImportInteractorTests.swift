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

@Suite("Import Firefox file")
struct FirefoxImportInteractorTests {
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
    func importFirefoxFile() async throws {
        // GIVEN
        let data = try loadFirefoxTestData()

        // WHEN
        let result = try await interactor.importService(.firefox, content: .file(data))

        // THEN
        // The Firefox.csv file contains 1 login
        #expect(result.items.count == 1)
        #expect(result.tags.isEmpty)
        #expect(result.itemsConvertedToSecureNotes == 0)

        // Verify item types
        let logins = result.items.filter { if case .login = $0 { return true } else { return false } }
        #expect(logins.count == 1)
    }

    // MARK: - Login Import Tests

    @Test
    func importLoginItemFromFirefoxFile() async throws {
        // GIVEN
        let data = try loadFirefoxTestData()

        // WHEN
        let result = try await interactor.importService(.firefox, content: .file(data))

        // THEN
        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let testLogin = try #require(logins.first)
        #expect(testLogin.name == "https://www.youtube.com")
        #expect(testLogin.content.username == "Rafael")

        let password = try #require(decrypt(testLogin.content.password))
        #expect(password == "09-0lk,fdstg4hhh")

        #expect(testLogin.content.uris?.first?.uri == "https://www.youtube.com")
        #expect(testLogin.content.uris?.first?.match == .domain)

        // Notes should contain additional fields (timeLastUsed formatted as date)
        let expectedTimeLastUsed = Date(exportTimestamp: 1765997173698).formatted(date: .abbreviated, time: .shortened)
        #expect(testLogin.content.notes == "Time Last Used: \(expectedTimeLastUsed)")
    }

    @Test
    func importLoginWithTimestamps() async throws {
        // GIVEN
        let data = try loadFirefoxTestData()

        // WHEN
        let result = try await interactor.importService(.firefox, content: .file(data))

        // THEN
        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let testLogin = try #require(logins.first)
        // Timestamps are in milliseconds: 1765997173698
        let expectedDate = Date(exportTimestamp: 1765997173698)
        #expect(testLogin.metadata.creationDate == expectedDate)
        #expect(testLogin.metadata.modificationDate == expectedDate)
    }

    @Test
    func importLoginWithCorrectVaultAndProtectionLevel() async throws {
        // GIVEN
        let data = try loadFirefoxTestData()

        // WHEN
        let result = try await interactor.importService(.firefox, content: .file(data))

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
    func importAllValuesFromFirefoxFile() async throws {
        // GIVEN - Use real implementations
        let realURIInteractor = URIInteractor(mainRepository: mockMainRepository)
        let realInteractor = ExternalServiceImportInteractor(
            mainRepository: mockMainRepository,
            uriInteractor: realURIInteractor,
            paymentCardUtilityInteractor: mockPaymentCardUtilityInteractor
        )

        let data = try loadFirefoxTestData()

        // WHEN
        let result = try await realInteractor.importService(.firefox, content: .file(data))

        // THEN - Verify result summary
        #expect(result.items.count == 1)
        #expect(result.tags.isEmpty)
        #expect(result.itemsConvertedToSecureNotes == 0)

        // Extract login
        let logins = result.items.compactMap { if case .login(let l) = $0 { return l } else { return nil } }
        #expect(logins.count == 1)

        // MARK: Login - "https://www.youtube.com"
        let loginItem = try #require(logins.first)
        #expect(loginItem.name == "https://www.youtube.com")
        #expect(loginItem.vaultId == testVaultID)
        #expect(loginItem.content.username == "Rafael")

        let loginPassword = try #require(decrypt(loginItem.content.password))
        #expect(loginPassword == "09-0lk,fdstg4hhh")

        #expect(loginItem.content.uris?[0].uri == "https://www.youtube.com")
        #expect(loginItem.content.uris?[0].match == .domain)
        let expectedTimeLastUsedComprehensive = Date(exportTimestamp: 1765997173698).formatted(date: .abbreviated, time: .shortened)
        #expect(loginItem.content.notes == "Time Last Used: \(expectedTimeLastUsedComprehensive)")
        #expect(loginItem.metadata.protectionLevel == .normal)
        #expect(loginItem.metadata.trashedStatus == .no)
        #expect(loginItem.metadata.tagIds == nil)

        // Verify timestamps (1765997173698 ms)
        let expectedDate = Date(exportTimestamp: 1765997173698)
        #expect(loginItem.metadata.creationDate == expectedDate)
        #expect(loginItem.metadata.modificationDate == expectedDate)
    }

    // MARK: - Error Handling Tests

    @Test
    func invalidCSVThrowsWrongFormat() async {
        // GIVEN
        let invalidData = "not,valid,csv,without,proper,headers".data(using: .utf8)!

        // WHEN/THEN
        await #expect(throws: ExternalServiceImportError.wrongFormat) {
            try await interactor.importService(.firefox, content: .file(invalidData))
        }
    }

    @Test
    func missingVaultThrowsWrongFormat() async throws {
        // GIVEN
        mockMainRepository.withSelectedVault(nil)
        let data = try loadFirefoxTestData()

        // WHEN/THEN
        await #expect(throws: ExternalServiceImportError.wrongFormat) {
            try await interactor.importService(.firefox, content: .file(data))
        }
    }

    @Test
    func emptyCSVWithHeadersReturnsEmptyResult() async throws {
        // GIVEN
        let csvData = "url,username,password,httpRealm,formActionOrigin,guid,timeCreated,timeLastUsed,timePasswordChanged\n".data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.firefox, content: .file(csvData))

        // THEN
        #expect(result.items.isEmpty)
        #expect(result.tags.isEmpty)
        #expect(result.itemsConvertedToSecureNotes == 0)
    }

    @Test
    func csvWithEmptyRowsSkipsEmptyRows() async throws {
        // GIVEN
        let csvData = """
            url,username,password,httpRealm,formActionOrigin,guid,timeCreated,timeLastUsed,timePasswordChanged
            "https://example.com","user1","pass1",,"","{guid1}","1765997173698","1765997173698","1765997173698"
            "","","",,"","","","",""
            "https://example2.com","user2","pass2",,"","{guid2}","1765997173698","1765997173698","1765997173698"
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.firefox, content: .file(csvData))

        // THEN
        #expect(result.items.count == 2)
    }

    @Test
    func importMultipleLogins() async throws {
        // GIVEN
        let csvData = """
            url,username,password,httpRealm,formActionOrigin,guid,timeCreated,timeLastUsed,timePasswordChanged
            "https://github.com","developer","secretpass123",,"https://github.com/session","{guid-1}","1765997173698","1765997173698","1765997173698"
            "https://gitlab.com","dev@company.com","anotherpass",,"https://gitlab.com/users/sign_in","{guid-2}","1765997173699","1765997173700","1765997173700"
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.firefox, content: .file(csvData))

        // THEN
        #expect(result.items.count == 2)

        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let githubLogin = logins.first { $0.name == "https://github.com" }
        #expect(githubLogin?.content.username == "developer")
        let githubPassword = decrypt(githubLogin?.content.password)
        #expect(githubPassword == "secretpass123")
        let expectedGithubTimeLastUsed = Date(exportTimestamp: 1765997173698).formatted(date: .abbreviated, time: .shortened)
        let expectedGithubNotes = """
            Form Action Origin: https://github.com/session
            Time Last Used: \(expectedGithubTimeLastUsed)
            """
        #expect(githubLogin?.content.notes == expectedGithubNotes)

        let gitlabLogin = logins.first { $0.name == "https://gitlab.com" }
        #expect(gitlabLogin?.content.username == "dev@company.com")
        let gitlabPassword = decrypt(gitlabLogin?.content.password)
        #expect(gitlabPassword == "anotherpass")
        let expectedGitlabTimeLastUsed = Date(exportTimestamp: 1765997173700).formatted(date: .abbreviated, time: .shortened)
        let expectedGitlabNotes = """
            Form Action Origin: https://gitlab.com/users/sign_in
            Time Last Used: \(expectedGitlabTimeLastUsed)
            """
        #expect(gitlabLogin?.content.notes == expectedGitlabNotes)
    }

    @Test
    func importLoginWithMissingOptionalFields() async throws {
        // GIVEN - CSV with missing optional fields
        let csvData = """
            url,username,password,httpRealm,formActionOrigin,guid,timeCreated,timeLastUsed,timePasswordChanged
            "https://test.com","testuser","testpass",,,"{test-guid}",,,
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.firefox, content: .file(csvData))

        // THEN
        #expect(result.items.count == 1)

        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let testLogin = try #require(logins.first)
        #expect(testLogin.name == "https://test.com")
        #expect(testLogin.content.username == "testuser")

        let password = try #require(decrypt(testLogin.content.password))
        #expect(password == "testpass")

        // Missing timestamps should use placeholder date
        #expect(testLogin.metadata.creationDate == Date.importPasswordPlaceholder)
        #expect(testLogin.metadata.modificationDate == Date.importPasswordPlaceholder)

        // No additional fields should result in nil notes
        #expect(testLogin.content.notes == nil)
    }

    // MARK: - Helper Methods

    private func loadFirefoxTestData() throws -> Data {
        guard let url = Bundle(for: MockMainRepository.self).url(forResource: "Firefox", withExtension: "csv") else {
            throw TestError.resourceNotFound("Firefox.csv test resource not found")
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
