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

@Suite("Import 1Password CSV file")
struct OnePasswordCSVImportInteractorTests {
    private let mockMainRepository: MockMainRepository
    private let mockURIInteractor: MockURIInteractor
    private let mockPaymentCardUtilityInteractor: MockPaymentCardUtilityInteractor
    private let interactor: ExternalServiceImportInteracting

    init() {
        mockMainRepository = MockMainRepository.defaultConfiguration()
        mockURIInteractor = MockURIInteractor()
        mockPaymentCardUtilityInteractor = MockPaymentCardUtilityInteractor()

        interactor = ExternalServiceImportInteractor(
            mainRepository: mockMainRepository,
            uriInteractor: mockURIInteractor,
            paymentCardUtilityInteractor: mockPaymentCardUtilityInteractor
        )
    }

    // MARK: - Full Import Test

    @Test
    func importOnePasswordCSVFile() async throws {
        // GIVEN
        let data = try loadOnePasswordTestData()

        // WHEN
        let result = try await interactor.importService(.onePassword, content: .file(data))

        // THEN
        // The 1Password.csv file contains 3 logins with 3 unique tags
        #expect(result.items.count == 2)
        #expect(result.tags.count == 3)
        #expect(result.itemsConvertedToSecureNotes == 0)

        // Verify item types
        let logins = result.items.filter { if case .login = $0 { return true } else { return false } }
        #expect(logins.count == 2)

        // Verify tags
        let tagNames = Set(result.tags.map(\.name))
        #expect(tagNames.contains("Starter Kit"))
        #expect(tagNames.contains("Rafael"))
        #expect(tagNames.contains("3 tag"))
    }

    // MARK: - Login Import Tests

    @Test
    func importFirstLoginItemFromOnePasswordCSV() async throws {
        // GIVEN
        let data = try loadOnePasswordTestData()

        // WHEN
        let result = try await interactor.importService(.onePassword, content: .file(data))

        // THEN
        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let testLogin = try #require(logins.first { $0.name == "Password" })
        #expect(testLogin.content.username == "rafols")

        let password = try #require(decrypt(testLogin.content.password))
        #expect(password == "y8gL676v7iyNrQWL7shE")

        #expect(testLogin.content.uris?.first?.uri == "https://2fas.com")
        #expect(testLogin.content.uris?.first?.match == .domain)

        // Notes should contain the original note plus additional OTPAuth info
        let notes = try #require(testLogin.content.notes)
        #expect(notes.contains("Notka password"))
    }

    @Test
    func importLoginWithCorrectVaultAndProtectionLevel() async throws {
        // GIVEN
        let data = try loadOnePasswordTestData()

        // WHEN
        let result = try await interactor.importService(.onePassword, content: .file(data))

        // THEN
        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let testLogin = try #require(logins.first)
        #expect(testLogin.vaultId == mockMainRepository.selectedVault?.id)
        #expect(testLogin.metadata.protectionLevel == .normal)
    }

    // MARK: - Archived Items Test

    @Test
    func archivedItemsAreSkipped() async throws {
        // GIVEN - CSV with archived item
        let csvData = """
            Title,Url,Username,Password,OTPAuth,Favorite,Archived,Tags,Notes
            "Active Item","https://active.com","user1","pass1",,false,false,,
            "Archived Item","https://archived.com","user2","pass2",,false,true,,
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.onePassword, content: .file(csvData))

        // THEN
        #expect(result.items.count == 1)

        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let testLogin = try #require(logins.first)
        #expect(testLogin.name == "Active Item")
    }

    // MARK: - Additional Fields Test

    @Test
    func additionalFieldsAreIncludedInNotes() async throws {
        // GIVEN - CSV with OTPAuth and Tags
        let csvData = """
            Title,Url,Username,Password,OTPAuth,Favorite,Archived,Tags,Notes
            "Test Item","https://test.com","testuser","testpass","otpauth://totp/Test?secret=ABC123",true,false,"work;important","Original note"
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.onePassword, content: .file(csvData))

        // THEN
        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let testLogin = try #require(logins.first)
        let notes = try #require(testLogin.content.notes)

        // Notes should contain original note and OTPAuth (but not tags - they are imported separately)
        #expect(notes.contains("Original note"))
        #expect(notes.contains("OTPAuth") || notes.contains("otpauth://"))

        // Tags should be imported as separate tags, not in notes
        #expect(result.tags.count == 2)
        let tagNames = Set(result.tags.map(\.name))
        #expect(tagNames.contains("work"))
        #expect(tagNames.contains("important"))

        // Verify item has the tag IDs assigned
        #expect(testLogin.metadata.tagIds?.count == 2)
    }

    // MARK: - Error Handling Tests

    @Test
    func invalidCSVThrowsWrongFormat() async {
        // GIVEN
        let invalidData = "not,valid,csv,headers".data(using: .utf8)!

        // WHEN/THEN
        await #expect(throws: ExternalServiceImportError.wrongFormat) {
            try await interactor.importService(.onePassword, content: .file(invalidData))
        }
    }

    @Test
    func missingRequiredHeadersThrowsWrongFormat() async {
        // GIVEN - CSV missing required "Password" header
        let csvData = """
            Title,Url,Username,Notes
            "Test","https://test.com","user","note"
            """.data(using: .utf8)!

        // WHEN/THEN
        await #expect(throws: ExternalServiceImportError.wrongFormat) {
            try await interactor.importService(.onePassword, content: .file(csvData))
        }
    }

    @Test
    func missingVaultThrowsWrongFormat() async throws {
        // GIVEN
        mockMainRepository.withSelectedVault(nil)
        let data = try loadOnePasswordTestData()

        // WHEN/THEN
        await #expect(throws: ExternalServiceImportError.wrongFormat) {
            try await interactor.importService(.onePassword, content: .file(data))
        }
    }

    @Test
    func emptyCSVWithHeadersReturnsEmptyResult() async throws {
        // GIVEN
        let csvData = "Title,Url,Username,Password,Notes\n".data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.onePassword, content: .file(csvData))

        // THEN
        #expect(result.items.isEmpty)
        #expect(result.tags.isEmpty)
        #expect(result.itemsConvertedToSecureNotes == 0)
    }

    @Test
    func csvWithEmptyRowsSkipsEmptyRows() async throws {
        // GIVEN
        let csvData = """
            Title,Url,Username,Password,Notes
            "Example 1","https://example1.com","user1","pass1","note1"
            "","","","",""
            "Example 2","https://example2.com","user2","pass2","note2"
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.onePassword, content: .file(csvData))

        // THEN
        #expect(result.items.count == 2)
    }

    @Test
    func importMultipleLogins() async throws {
        // GIVEN
        let csvData = """
            Title,Url,Username,Password,Notes
            "GitHub","https://github.com","developer","secretpass123","Work account"
            "GitLab","https://gitlab.com","dev@company.com","anotherpass","Personal"
            "BitBucket","https://bitbucket.org","bituser","bitpass",""
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.onePassword, content: .file(csvData))

        // THEN
        #expect(result.items.count == 3)

        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let githubLogin = logins.first { $0.name == "GitHub" }
        #expect(githubLogin?.content.username == "developer")
        let githubPassword = decrypt(githubLogin?.content.password)
        #expect(githubPassword == "secretpass123")
        #expect(githubLogin?.content.notes == "Work account")

        let gitlabLogin = logins.first { $0.name == "GitLab" }
        #expect(gitlabLogin?.content.username == "dev@company.com")
        let gitlabPassword = decrypt(gitlabLogin?.content.password)
        #expect(gitlabPassword == "anotherpass")
        #expect(gitlabLogin?.content.notes == "Personal")

        let bitbucketLogin = logins.first { $0.name == "BitBucket" }
        #expect(bitbucketLogin?.content.username == "bituser")
        #expect(bitbucketLogin?.content.notes == nil)
    }

    @Test
    func importLoginWithMissingOptionalFields() async throws {
        // GIVEN - CSV with missing optional fields (empty URL and notes)
        let csvData = """
            Title,Url,Username,Password,Notes
            "Test Item","","testuser","testpass",""
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.onePassword, content: .file(csvData))

        // THEN
        #expect(result.items.count == 1)

        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let testLogin = try #require(logins.first)
        #expect(testLogin.name == "Test Item")
        #expect(testLogin.content.username == "testuser")

        let password = try #require(decrypt(testLogin.content.password))
        #expect(password == "testpass")

        #expect(testLogin.content.uris == nil)
        #expect(testLogin.content.notes == nil)
    }

    @Test
    func importLoginWithEmptyPassword() async throws {
        // GIVEN - CSV with empty password
        let csvData = """
            Title,Url,Username,Password,Notes
            "Test Item","https://test.com","testuser","","Note"
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.onePassword, content: .file(csvData))

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
    func importLoginWithSpecialCharactersInFields() async throws {
        // GIVEN - CSV with special characters
        let csvData = """
            Title,Url,Username,Password,Notes
            "Test ""Quoted"" Item","https://test.com","user@email.com","p@ss,word!#$%","Note with ""quotes"" and special chars: <>&"
            """.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.onePassword, content: .file(csvData))

        // THEN
        #expect(result.items.count == 1)

        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let testLogin = try #require(logins.first)
        #expect(testLogin.name == "Test \"Quoted\" Item")
        #expect(testLogin.content.username == "user@email.com")

        let password = try #require(decrypt(testLogin.content.password))
        #expect(password == "p@ss,word!#$%")

        let notes = try #require(testLogin.content.notes)
        #expect(notes.contains("\"quotes\""))
    }

    // MARK: - Helper Methods

    private func loadOnePasswordTestData() throws -> Data {
        guard let url = Bundle(for: MockMainRepository.self).url(forResource: "1Password", withExtension: "csv") else {
            throw TestError.resourceNotFound("1Password.csv test resource not found")
        }
        return try Data(contentsOf: url)
    }
    
    private func decrypt(_ data: Data?) -> String? {
        DataTests.decrypt(data, using: mockMainRepository)
    }
}

extension OnePasswordCSVImportInteractorTests {
    
    @Suite("Import 1Password test file")
    struct IntegrationTests {
        
        private let mockMainRepository = MockMainRepository.defaultConfiguration()
        
        private let paymentCardUtilityInteractor = PaymentCardUtilityInteractor()
        private let uriInteractor: URIInteractor
        
        private let testVaultID = UUID()

        init() {
            self.uriInteractor = URIInteractor(mainRepository: mockMainRepository)
        }
        
        @Test
        func importCSV() async throws {
            let interactor = ExternalServiceImportInteractor(
                mainRepository: mockMainRepository,
                uriInteractor: uriInteractor,
                paymentCardUtilityInteractor: paymentCardUtilityInteractor
            )

            let data = try loadOnePasswordTestData()

            // WHEN
            let result = try await interactor.importService(.onePassword, content: .file(data))

            // THEN - Verify result summary
            #expect(result.items.count == 2)
            #expect(result.tags.count == 3)
            #expect(result.itemsConvertedToSecureNotes == 0)

            // Verify tags
            let tagNames = Set(result.tags.map(\.name))
            #expect(tagNames.contains("Starter Kit"))
            #expect(tagNames.contains("Rafael"))
            #expect(tagNames.contains("3 tag"))

            // Create tag name to ID mapping for verification
            let tagNameToId = Dictionary(uniqueKeysWithValues: result.tags.map { ($0.name, $0.tagID) })

            // Extract logins
            let logins = result.items.compactMap { if case .login(let l) = $0 { return l } else { return nil } }
            #expect(logins.count == 2)

            // MARK: Login - "Password"
            let passwordItem = try #require(logins.first { $0.name == "Password" })
            #expect(passwordItem.vaultId == mockMainRepository.selectedVault?.vaultID)
            #expect(passwordItem.content.username == "rafols")

            let passwordValue = try #require(decrypt(passwordItem.content.password))
            #expect(passwordValue == "y8gL676v7iyNrQWL7shE")

            #expect(passwordItem.content.uris?[0].uri == "https://2fas.com")
            #expect(passwordItem.content.uris?[0].match == .domain)
            #expect(passwordItem.metadata.protectionLevel == .normal)
            #expect(passwordItem.metadata.trashedStatus == .no)
            #expect(passwordItem.metadata.creationDate == Date.importPasswordPlaceholder)
            #expect(passwordItem.metadata.modificationDate == Date.importPasswordPlaceholder)

            #expect(passwordItem.metadata.tagIds?.count == 1)
            #expect(passwordItem.metadata.tagIds?.contains(tagNameToId["Rafael"]!) == true)
            #expect(passwordItem.content.notes == "Notka password")

            // MARK: Login - "Login dla Maćka" (has 3 tags)
            let multiTagItem = try #require(logins.first { $0.name == "Login dla Maćka" })
            #expect(multiTagItem.metadata.tagIds?.count == 3)
            #expect(multiTagItem.metadata.tagIds?.contains(tagNameToId["3 tag"]!) == true)
            #expect(multiTagItem.metadata.tagIds?.contains(tagNameToId["Rafael"]!) == true)
            #expect(multiTagItem.metadata.tagIds?.contains(tagNameToId["Starter Kit"]!) == true)
            #expect(multiTagItem.content.notes == "Login z wieloma tagami")
        }

        // MARK: - 1PUX Import Test

        @Test
        func import1Pux() async throws {
            let interactor = ExternalServiceImportInteractor(
                mainRepository: mockMainRepository,
                uriInteractor: uriInteractor,
                paymentCardUtilityInteractor: paymentCardUtilityInteractor
            )

            let data = try load1PuxTestData()

            // WHEN
            let result = try await interactor.importService(.onePassword, content: .file(data))

            // THEN - Verify result summary
            // 2 logins + 2 secure notes + 2 credit cards + 2 converted to secure notes = 8 items
            #expect(result.items.count == 8)
            #expect(result.tags.count == 3)
            #expect(result.itemsConvertedToSecureNotes == 2)

            // Verify tags
            let tagNames = Set(result.tags.map(\.name))
            #expect(tagNames.contains("Starter Kit"))
            #expect(tagNames.contains("Rafael"))
            #expect(tagNames.contains("3 tag"))

            // Create tag name to ID mapping for verification
            let tagNameToId = Dictionary(uniqueKeysWithValues: result.tags.map { ($0.name, $0.tagID) })

            // Extract items by type
            let logins = result.items.compactMap { if case .login(let l) = $0 { return l } else { return nil } }
            let secureNotes = result.items.compactMap { if case .secureNote(let n) = $0 { return n } else { return nil } }
            let creditCards = result.items.compactMap { if case .paymentCard(let c) = $0 { return c } else { return nil } }

            #expect(logins.count == 2)
            #expect(secureNotes.count == 4) // 2 original + 2 converted
            #expect(creditCards.count == 2)

            // MARK: Login - "Password"
            let passwordItem = try #require(logins.first { $0.name == "Password" })
            #expect(passwordItem.vaultId == mockMainRepository.selectedVault?.vaultID)
            #expect(passwordItem.content.username == "rafols")

            let passwordValue = try #require(decrypt(passwordItem.content.password))
            #expect(passwordValue == "y8gL676v7iyNrQWL7shE")

            #expect(passwordItem.content.uris?[0].uri == "https://2fas.com")
            #expect(passwordItem.metadata.tagIds?.count == 1)
            #expect(passwordItem.metadata.tagIds?.contains(tagNameToId["Rafael"]!) == true)
            #expect(passwordItem.content.notes == "Notka password")

            // MARK: Login - "Login dla Maćka" (has 3 tags)
            let multiTagItem = try #require(logins.first { $0.name == "Login dla Maćka" })
            #expect(multiTagItem.content.username == "Rafael")

            let multiTagPassword = try #require(decrypt(multiTagItem.content.password))
            #expect(multiTagPassword == "UXcDQuZuE9ohNoWAgnFi")

            #expect(multiTagItem.metadata.tagIds?.count == 3)
            #expect(multiTagItem.metadata.tagIds?.contains(tagNameToId["3 tag"]!) == true)
            #expect(multiTagItem.metadata.tagIds?.contains(tagNameToId["Rafael"]!) == true)
            #expect(multiTagItem.metadata.tagIds?.contains(tagNameToId["Starter Kit"]!) == true)
            #expect(multiTagItem.content.notes == "Login z wieloma tagami")

            // MARK: Secure Note - "Notka 2"
            let notka2 = try #require(secureNotes.first { $0.name == "Notka 2" })
            let notka2Text = try #require(decrypt(notka2.content.text))
            #expect(notka2Text == "Notka testowa 2FAS")
            #expect(notka2.metadata.tagIds?.count == 1)
            #expect(notka2.metadata.tagIds?.contains(tagNameToId["Starter Kit"]!) == true)

            // MARK: Secure Note - "Secure Note"
            let secureNote = try #require(secureNotes.first { $0.name == "Secure Note" })
            let secureNoteText = try #require(decrypt(secureNote.content.text))
            #expect(secureNoteText == "Lorem Ipsum")
            #expect(secureNote.metadata.tagIds?.count == 1)
            #expect(secureNote.metadata.tagIds?.contains(tagNameToId["Rafael"]!) == true)

            // MARK: Credit Card - with Starter Kit tag
            let cardWithTag = try #require(creditCards.first { $0.metadata.tagIds?.isEmpty == false })
            #expect(cardWithTag.content.cardHolder == "2FAS")

            let cardNumber = try #require(decrypt(cardWithTag.content.cardNumber))
            #expect(cardNumber == "4110968834331988")

            let cvv = try #require(decrypt(cardWithTag.content.securityCode))
            #expect(cvv == "338")

            let expiry = try #require(decrypt(cardWithTag.content.expirationDate))
            #expect(expiry == "11/29")

            #expect(cardWithTag.metadata.tagIds?.count == 1)
            #expect(cardWithTag.metadata.tagIds?.contains(tagNameToId["Starter Kit"]!) == true)

            // Verify notes contain PIN
            #expect(cardWithTag.content.notes?.contains("PIN: 2356") == true)

            // MARK: Credit Card - without tags (Thomas Brown)
            let cardWithoutTag = try #require(creditCards.first { $0.metadata.tagIds == nil })
            #expect(cardWithoutTag.content.cardHolder == "Thomas Brown")

            // MARK: Converted items - Identity and Driver License
            let identityNote = secureNotes.first { $0.name?.contains("Identity") == true }
            #expect(identityNote != nil)

            let driverLicenseNote = secureNotes.first { $0.name?.contains("Driver License") == true }
            #expect(driverLicenseNote != nil)
        }
        
        private func loadOnePasswordTestData() throws -> Data {
            guard let url = Bundle(for: MockMainRepository.self).url(forResource: "1Password", withExtension: "csv") else {
                throw TestError.resourceNotFound("1Password.csv test resource not found")
            }
            return try Data(contentsOf: url)
        }
        

        private func load1PuxTestData() throws -> Data {
            guard let url = Bundle(for: MockMainRepository.self).url(forResource: "1Password", withExtension: "1pux") else {
                throw TestError.resourceNotFound("1Password.1pux test resource not found")
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
