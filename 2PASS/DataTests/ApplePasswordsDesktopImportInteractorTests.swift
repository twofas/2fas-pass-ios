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

@Suite("Import Apple Passwords Desktop file")
struct ApplePasswordsDesktopImportInteractorTests {
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
    func importApplePasswordsDesktopFile() async throws {
        // GIVEN
        let data = try loadApplePasswordsDesktopTestData()

        // WHEN
        let result = try await interactor.importService(.applePasswordsDesktop, content: .file(data))

        // THEN
        // The ApplePasswordsDesktop.csv file contains 3 logins
        #expect(result.items.count == 3)
        #expect(result.tags.isEmpty)
        #expect(result.itemsConvertedToSecureNotes == 0)

        // Verify item types
        let logins = result.items.filter { if case .login = $0 { return true } else { return false } }
        #expect(logins.count == 3)
    }

    // MARK: - Login Import Tests

    @Test
    func importLoginItemFromApplePasswordsDesktopFile() async throws {
        // GIVEN
        let data = try loadApplePasswordsDesktopTestData()

        // WHEN
        let result = try await interactor.importService(.applePasswordsDesktop, content: .file(data))

        // THEN
        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        // First login item: console.acrcloud.com
        // Note: Username in CSV has leading space, and title suffix removal only works
        // when username matches exactly (so the suffix won't be removed here)
        let testLogin = try #require(logins.first { $0.name == "console.acrcloud.com" })
        #expect(testLogin.content.username == "user@gmail.com")

        let password = try #require(decrypt(testLogin.content.password))
        #expect(password == "koqma4-kyCxov-vycpur")

        #expect(testLogin.content.uris?.first?.uri == "https://console.acrcloud.com/")
        #expect(testLogin.content.uris?.first?.match == .domain)

        // Notes should contain the original note (OTPAuth column is empty in the test CSV)
        #expect(testLogin.content.notes == "Custom note")
    }

    @Test
    func importLoginWithCorrectVaultAndProtectionLevel() async throws {
        // GIVEN
        let data = try loadApplePasswordsDesktopTestData()

        // WHEN
        let result = try await interactor.importService(.applePasswordsDesktop, content: .file(data))

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

    @Test
    func importLoginRemovesUsernameSuffixFromTitle() async throws {
        // GIVEN - CSV where Title contains username suffix
        let csvData = """
            Title,URL,Username,Password,Notes
            "example.com (john@example.com)","https://example.com/","john@example.com","secret123","My note"
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.applePasswordsDesktop, content: .file(csvData))

        // THEN
        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let testLogin = try #require(logins.first)
        // The username suffix should be removed from the title
        #expect(testLogin.name == "example.com")
    }

    // MARK: - Comprehensive Import Test

    @Test
    func importAllValuesFromApplePasswordsDesktopFile() async throws {
        // GIVEN - Use real implementations
        let realURIInteractor = URIInteractor(mainRepository: mockMainRepository)
        let realInteractor = ExternalServiceImportInteractor(
            mainRepository: mockMainRepository,
            uriInteractor: realURIInteractor,
            paymentCardUtilityInteractor: mockPaymentCardUtilityInteractor
        )

        let data = try loadApplePasswordsDesktopTestData()

        // WHEN
        let result = try await realInteractor.importService(.applePasswordsDesktop, content: .file(data))

        // THEN - Verify result summary
        #expect(result.items.count == 3)
        #expect(result.tags.isEmpty)
        #expect(result.itemsConvertedToSecureNotes == 0)

        // Extract logins
        let logins = result.items.compactMap { if case .login(let l) = $0 { return l } else { return nil } }
        #expect(logins.count == 3)

        // MARK: Login - "console.acrcloud.com (user@gmail.com)"
        // Note: Username in CSV has leading space, so title suffix removal doesn't apply
        let acrcloudLogin = try #require(logins.first { $0.name == "console.acrcloud.com" })
        #expect(acrcloudLogin.vaultId == testVaultID)
        #expect(acrcloudLogin.content.username == "user@gmail.com")

        let acrcloudPassword = try #require(decrypt(acrcloudLogin.content.password))
        #expect(acrcloudPassword == "koqma4-kyCxov-vycpur")

        #expect(acrcloudLogin.content.uris?[0].uri == "https://console.acrcloud.com/")
        #expect(acrcloudLogin.content.uris?[0].match == .domain)
        #expect(acrcloudLogin.content.notes == "Custom note")
        #expect(acrcloudLogin.metadata.protectionLevel == .normal)
        #expect(acrcloudLogin.metadata.trashedStatus == .no)
        #expect(acrcloudLogin.metadata.tagIds == nil)
        #expect(acrcloudLogin.metadata.creationDate == Date.importPasswordPlaceholder)
        #expect(acrcloudLogin.metadata.modificationDate == Date.importPasswordPlaceholder)

        // MARK: Login - "adobeid-na1.services.adobe.com"
        // This one has correct username without leading space, so suffix removal works
        let adobeNa1Login = try #require(logins.first { $0.name == "adobeid-na1.services.adobe.com" })
        #expect(adobeNa1Login.content.username == "user2@cohesiva.com")

        let adobeNa1Password = try #require(decrypt(adobeNa1Login.content.password))
        #expect(adobeNa1Password == "uMF-mL3-yVH-eYM")

        // No notes for this item
        #expect(adobeNa1Login.content.notes == nil)

        // MARK: Login - "adobeid.services.adobe.com (maciej.szewczyk@cohesiva.com)"
        // This one has empty URL and Username, so title keeps the suffix and uris is nil
        let adobeLogin = try #require(logins.first { $0.name == "adobeid.services.adobe.com (maciej.szewczyk@cohesiva.com)" })
        #expect(adobeLogin.content.username == nil)
        #expect(adobeLogin.content.uris == nil)

        let adobePassword = try #require(decrypt(adobeLogin.content.password))
        #expect(adobePassword == "austyf-6jekzo-wivhIx")

        #expect(adobeLogin.content.notes == nil)
    }

    // MARK: - Unknown Headers Test

    @Test
    func importLoginWithUnknownHeaders() async throws {
        // GIVEN - CSV with unknown/future headers
        let csvData = """
            Title,URL,Username,Password,Notes,OTPAuth,future_field,another_new_column
            "www.example.com","https://www.example.com/","testuser","testpass123","My note","otpauth://totp/Example","future value","new data"
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.applePasswordsDesktop, content: .file(csvData))

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
        #expect(notes.contains("OTPAuth: otpauth://totp/Example"))
    }

    @Test
    func importLoginWithUnknownHeadersNoOriginalNote() async throws {
        // GIVEN - CSV with unknown headers but no original note
        let csvData = """
            Title,URL,Username,Password,Notes,custom_data
            "www.example.com","https://www.example.com/","testuser","testpass123","","some custom value"
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.applePasswordsDesktop, content: .file(csvData))

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
            try await interactor.importService(.applePasswordsDesktop, content: .file(invalidData))
        }
    }

    @Test
    func missingVaultThrowsWrongFormat() async throws {
        // GIVEN
        mockMainRepository.withSelectedVault(nil)
        let data = try loadApplePasswordsDesktopTestData()

        // WHEN/THEN
        await #expect(throws: ExternalServiceImportError.wrongFormat) {
            try await interactor.importService(.applePasswordsDesktop, content: .file(data))
        }
    }

    @Test
    func emptyCSVWithHeadersReturnsEmptyResult() async throws {
        // GIVEN
        let csvData = "Title,URL,Username,Password,Notes\n".data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.applePasswordsDesktop, content: .file(csvData))

        // THEN
        #expect(result.items.isEmpty)
        #expect(result.tags.isEmpty)
        #expect(result.itemsConvertedToSecureNotes == 0)
    }

    @Test
    func csvWithEmptyRowsSkipsEmptyRows() async throws {
        // GIVEN
        let csvData = """
            Title,URL,Username,Password,Notes
            "www.example.com","https://example.com","user1","pass1","note1"
            "","","","",""
            "www.example2.com","https://example2.com","user2","pass2","note2"
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.applePasswordsDesktop, content: .file(csvData))

        // THEN
        #expect(result.items.count == 2)
    }

    @Test
    func importMultipleLogins() async throws {
        // GIVEN
        let csvData = """
            Title,URL,Username,Password,Notes
            "github.com","https://github.com","developer","secretpass123","Work account"
            "gitlab.com","https://gitlab.com","dev@company.com","anotherpass","Personal"
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.applePasswordsDesktop, content: .file(csvData))

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
            Title,URL,Username,Password,Notes
            "test.com","https://test.com","testuser","testpass",""
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.applePasswordsDesktop, content: .file(csvData))

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
            Title,URL,Username,Password,Notes
            "test.com","https://test.com","testuser","","Note"
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.applePasswordsDesktop, content: .file(csvData))

        // THEN
        #expect(result.items.count == 1)

        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let testLogin = try #require(logins.first)
        #expect(testLogin.content.password == nil)
    }

    @Test
    func importLoginWithMinimalData() async throws {
        // GIVEN - CSV with only required fields (empty URL, username, password)
        let csvData = """
            Title,URL,Username,Password,Notes
            "adobeid.services.adobe.com (maciej.szewczyk@cohesiva.com)","","","austyf-6jekzo-wivhIx",""
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.applePasswordsDesktop, content: .file(csvData))

        // THEN
        #expect(result.items.count == 1)

        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let testLogin = try #require(logins.first)
        // Username is empty so title remains unchanged
        #expect(testLogin.name == "adobeid.services.adobe.com (maciej.szewczyk@cohesiva.com)")
        #expect(testLogin.content.username == nil)
        #expect(testLogin.content.uris == nil)

        let password = try #require(decrypt(testLogin.content.password))
        #expect(password == "austyf-6jekzo-wivhIx")
    }

    // MARK: - Helper Methods

    private func loadApplePasswordsDesktopTestData() throws -> Data {
        guard let url = Bundle(for: MockMainRepository.self)
            .url(forResource: "ApplePasswordsDesktop", withExtension: "csv") else {
            throw TestError.resourceNotFound("ApplePasswordsDesktop.csv test resource not found")
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
