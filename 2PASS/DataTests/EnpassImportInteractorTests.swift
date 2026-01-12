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

@Suite("Import Enpass file")
struct EnpassImportInteractorTests {
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
    func importEnpassFile() async throws {
        // GIVEN
        mockPaymentCardUtilityInteractor
            .withDetectCardIssuer { _ in .visa }
            .withCardNumberMask { _ in "5581" }

        let data = try loadEnpassTestData()

        // WHEN
        let result = try await interactor.importService(.enpass, content: .file(data))

        // THEN
        // The Enpass.json file contains:
        // - 3 logins (login + password categories)
        // - 1 credit card
        // - 1 secure note
        // - 1 finance item (converted to secure note)
        #expect(result.items.count == 6)
        #expect(result.tags.count == 4)
        #expect(result.itemsConvertedToSecureNotes == 1)

        // Verify item types
        let logins = result.items.filter { if case .login = $0 { return true } else { return false } }
        let cards = result.items.filter { if case .paymentCard = $0 { return true } else { return false } }
        let notes = result.items.filter { if case .secureNote = $0 { return true } else { return false } }

        #expect(logins.count == 3)
        #expect(cards.count == 1)
        #expect(notes.count == 2)
    }

    // MARK: - Login Import Tests

    @Test
    func importLoginItemFromEnpassFile() async throws {
        // GIVEN
        let data = try loadEnpassTestData()

        // WHEN
        let result = try await interactor.importService(.enpass, content: .file(data))

        // THEN
        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let testLogin = logins.first { $0.name == "testenpass" }
        #expect(testLogin != nil)
        #expect(testLogin?.content.username == "testenpass")
        #expect(testLogin?.content.password != nil)
        #expect(testLogin?.content.uris?.first?.uri == "https://www.youtube.com/")
        #expect(testLogin?.content.notes?.contains("Login test note") ?? false)
        // TOTP and additional fields should be in notes
        #expect(testLogin?.content.notes?.contains("One-time code") ?? false)
    }

    @Test
    func importLoginItemWithEmailAsUsername() async throws {
        // GIVEN
        let data = try loadEnpassTestData()

        // WHEN
        let result = try await interactor.importService(.enpass, content: .file(data))

        // THEN
        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        // "wdas" login has username "sdwasd" and email "wdawdad"
        let wdasLogin = try #require(logins.first { $0.name == "Bez username" })
        #expect(wdasLogin.content.username == "Example@gmail.com")
    }

    // MARK: - Password Category Tests

    @Test
    func importPasswordCategory() async throws {
        // GIVEN
        let data = try loadEnpassTestData()

        // WHEN
        let result = try await interactor.importService(.enpass, content: .file(data))

        // THEN
        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        // Password category should be imported as login
        let passwordItem = logins.first { $0.name == "Password" }
        #expect(passwordItem != nil)
    }

    // MARK: - Credit Card Import Tests

    @Test
    func importCreditCardItem() async throws {
        // GIVEN
        mockPaymentCardUtilityInteractor
            .withCardNumberMask { _ in "****5581" }
            .withDetectCardIssuer { _ in .visa }

        let data = try loadEnpassTestData()

        // WHEN
        let result = try await interactor.importService(.enpass, content: .file(data))

        // THEN
        let cards = result.items.compactMap { item -> PaymentCardItemData? in
            if case .paymentCard(let card) = item { return card }
            return nil
        }

        #expect(cards.count == 1)
        let creditCard = cards.first
        #expect(creditCard?.name == "Credit Card")
        #expect(creditCard?.content.cardHolder == "Joe Schmoe")
        #expect(creditCard?.content.cardNumber != nil)
        #expect(creditCard?.content.securityCode != nil)
        #expect(creditCard?.content.expirationDate != nil)
        #expect(creditCard?.content.cardNumberMask == "****5581")
        #expect(creditCard?.content.cardIssuer == PaymentCardIssuer.visa.rawValue)
        // PIN should be in notes as additional info
        #expect(creditCard?.content.notes?.contains("PIN") ?? false)
        #expect(creditCard?.content.notes?.contains("Karta kredytowa notatka") ?? false)
    }

    // MARK: - Secure Note Import Tests

    @Test
    func importSecureNoteItem() async throws {
        // GIVEN
        let data = try loadEnpassTestData()

        // WHEN
        let result = try await interactor.importService(.enpass, content: .file(data))

        // THEN
        let notes = result.items.compactMap { item -> SecureNoteItemData? in
            if case .secureNote(let note) = item { return note }
            return nil
        }

        let noteItem = notes.first { $0.name == "Note" }
        #expect(noteItem != nil)
        #expect(noteItem?.content.text != nil)
    }

    // MARK: - Conversion to Secure Notes Tests

    @Test
    func importFinanceItemAsSecureNote() async throws {
        // GIVEN
        let data = try loadEnpassTestData()

        // WHEN
        let result = try await interactor.importService(.enpass, content: .file(data))

        // THEN
        #expect(result.itemsConvertedToSecureNotes == 1)

        let notes = result.items.compactMap { item -> SecureNoteItemData? in
            if case .secureNote(let note) = item { return note }
            return nil
        }

        let bankAccount = notes.first { $0.name?.contains("(Finance)") ?? false }
        #expect(bankAccount != nil)
        #expect(bankAccount?.name?.contains("Bank account") ?? false)
    }

    // MARK: - Folder/Tag Import Tests

    @Test
    func importFoldersAsTags() async throws {
        // GIVEN
        let data = try loadEnpassTestData()

        // WHEN
        let result = try await interactor.importService(.enpass, content: .file(data))

        // THEN
        // Enpass.json has 3 folders: Test, Erunestian (child of Test), Rafael (child of Erunestian)
        #expect(result.tags.count == 4)

        let tagNames = result.tags.map { $0.name }
        #expect(tagNames.contains("Test"))
        #expect(tagNames.contains("Erunestian"))
        #expect(tagNames.contains("Rafael"))
    }

    @Test
    func importItemWithNestedFolderHierarchy() async throws {
        // GIVEN
        let data = try loadEnpassTestData()

        // WHEN
        let result = try await interactor.importService(.enpass, content: .file(data))

        // THEN
        // "wdas" item is in folder "Rafael" which is nested under "Erunestian" -> "Test"
        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let wdasLogin = try #require(logins.first { $0.name == "Bez username" })
        // Should have 3 tags (Rafael + Erunestian + 2)
        #expect(wdasLogin.metadata.tagIds?.count == 3)
    }

    // MARK: - Comprehensive Import Test

    @Test
    func importAllValuesFromEnpassFile() async throws {
        // GIVEN - Use real implementations
        let realPaymentCardUtilityInteractor = PaymentCardUtilityInteractor()
        let realURIInteractor = URIInteractor(mainRepository: mockMainRepository)
        let realInteractor = ExternalServiceImportInteractor(
            mainRepository: mockMainRepository,
            uriInteractor: realURIInteractor,
            paymentCardUtilityInteractor: realPaymentCardUtilityInteractor
        )

        let data = try loadEnpassTestData()

        // WHEN
        let result = try await realInteractor.importService(.enpass, content: .file(data))

        // THEN - Verify result summary
        #expect(result.items.count == 6)
        #expect(result.tags.count == 4)
        #expect(result.itemsConvertedToSecureNotes == 1)

        // Extract items by type
        let logins = result.items.compactMap { if case .login(let l) = $0 { return l } else { return nil } }
        let cards = result.items.compactMap { if case .paymentCard(let c) = $0 { return c } else { return nil } }
        let notes = result.items.compactMap { if case .secureNote(let n) = $0 { return n } else { return nil } }

        #expect(logins.count == 3)
        #expect(cards.count == 1)
        #expect(notes.count == 2)

        // MARK: Tags (folders)
        let tagNames = Set(result.tags.map { $0.name })
        #expect(tagNames == Set(["Test", "Erunestian", "Rafael", "2"]))
        for tag in result.tags {
            #expect(tag.vaultID == testVaultID)
        }

        // MARK: Login 1 - "wdas"
        let withoutUsername = try #require(logins.first { $0.name == "Bez username" })
        #expect(withoutUsername.vaultId == testVaultID)
        #expect(withoutUsername.content.username == "Example@gmail.com")

        let withoutUsernamePassword = try #require(decrypt(withoutUsername.content.password))
        #expect(withoutUsernamePassword == "kt{PK\\/l2C\\YvYCebd/9LUI^=b}Sx7MD")
        #expect(withoutUsername.content.uris?[0].uri == "https://www.amazon.pl/")
        #expect(withoutUsername.content.uris?[0].match == .domain)
        #expect(withoutUsername.content.notes == "E-mail: Example@gmail.com")
        #expect(withoutUsername.metadata.protectionLevel == .normal)
        #expect(withoutUsername.metadata.trashedStatus == .no)

        #expect(withoutUsername.metadata.tagIds?.count == 3)
        let wdasTagNames = Set(withoutUsername.metadata.tagIds?.compactMap { tagId in
            result.tags.first { $0.tagID == tagId }?.name
        } ?? [])
        #expect(wdasTagNames == Set(["Rafael", "Erunestian", "Test"]))
        
        #expect(withoutUsername.metadata.creationDate == Date(timeIntervalSince1970: 1758641924))
        #expect(withoutUsername.metadata.modificationDate == Date(timeIntervalSince1970: 1765974423))

        // MARK: Login 2 - "testenpass"
        let testenpassLogin = try #require(logins.first { $0.name == "testenpass" })
        #expect(testenpassLogin.vaultId == testVaultID)
        #expect(testenpassLogin.content.username == "testenpass")
        // Decrypt and verify password
        let testenpassPassword = try #require(decrypt(testenpassLogin.content.password))
        #expect(testenpassPassword == "UyLmhARSgHe5DlS5e]g,G9DydLx]&^67")
        #expect(testenpassLogin.content.uris?.first?.uri == "https://www.youtube.com/")
        #expect(testenpassLogin.content.uris?.first?.match == .domain)
        // Notes should contain: original note + additional fields (email, phone, TOTP, security Q&A)
        let expectedTestenpassNotes = """
            Login test note

            E-mail: wdasdwad
            Phone number: 606505404
            One-time code: 2FASTEST
            Security question: Dog
            Security answer: Husky
            """
        #expect(testenpassLogin.content.notes == expectedTestenpassNotes)
        // In folder "Erunestian" -> should inherit tags: Erunestian, Test
        #expect(testenpassLogin.metadata.tagIds?.count == 1)
        let testenpassTagNames = Set(testenpassLogin.metadata.tagIds?.compactMap { tagId in
            result.tags.first { $0.tagID == tagId }?.name
        } ?? [])
        #expect(testenpassTagNames == Set(["Erunestian"]))
        
        #expect(testenpassLogin.metadata.creationDate == Date(timeIntervalSince1970: 1758641966))
        #expect(testenpassLogin.metadata.modificationDate == Date(timeIntervalSince1970: 1765906550))

        // MARK: Login 3 - "Password" (password category -> login)
        let passwordLogin = try #require(logins.first { $0.name == "Password" })
        #expect(passwordLogin.vaultId == testVaultID)
        #expect(passwordLogin.content.username == "Proton")
        let passwordLoginPassword = try #require(decrypt(passwordLogin.content.password))
        #expect(passwordLoginPassword == "9U#@XFq.TM;t]-lc~j^J{[&lcAZE@o64")
        #expect(passwordLogin.content.uris == nil)
        let expectedPasswordNotes = """
            Password note

            Access: Test do akcesu
            """
        #expect(passwordLogin.content.notes == expectedPasswordNotes)
        // In folder "Erunestian" -> should have 1 tag
        #expect(passwordLogin.metadata.tagIds?.count == 1)
        let passwordTagNames = Set(passwordLogin.metadata.tagIds?.compactMap { tagId in
            result.tags.first { $0.tagID == tagId }?.name
        } ?? [])
        #expect(passwordTagNames == Set(["Erunestian"]))
        
        #expect(passwordLogin.metadata.creationDate == Date(timeIntervalSince1970: 1765904315))
        #expect(passwordLogin.metadata.modificationDate == Date(timeIntervalSince1970: 1765974325))

        // MARK: Credit Card - "Credit Card"
        let creditCard = try #require(cards.first)
        #expect(creditCard.name == "Credit Card")
        #expect(creditCard.vaultId == testVaultID)
        #expect(creditCard.content.cardHolder == "Joe Schmoe")
        // Decrypt and verify card fields
        let cardNumber = try #require(decrypt(creditCard.content.cardNumber))
        #expect(cardNumber == "4179078730395581")
        let securityCode = try #require(decrypt(creditCard.content.securityCode))
        #expect(securityCode == "354")
        let expirationDate = try #require(decrypt(creditCard.content.expirationDate))
        #expect(expirationDate == "11/29")
        #expect(creditCard.content.cardNumberMask == "5581")
        #expect(creditCard.content.cardIssuer == PaymentCardIssuer.visa.rawValue)
        // Notes should contain: original note + PIN + additional fields
        let expectedCreditCardNotes = """
            Karta kredytowa notatka

            PIN: 4098
            Username: Erunestian
            Login password: QWeUc6JG@fyCWB9pkh5=[*XLz2$fvrH)
            Transaction password: )Y*{oO2z(ny<V{>U6-m}6QtL>Sur5WP{
            Website: https://login.ingbank.pl/mojeing/app/#login-oauth2/ref=3KtYqj9iTFTBYfpzHk3PmNeTjczqUxnB
            Issuing bank: ING
            Issued on: 10/2024
            Valid from: 11/2024
            Credit limit: 100000
            Withdrawal limit: 10000
            Interest rate: 4
            If lost, call: 303202101
            """
        #expect(creditCard.content.notes == expectedCreditCardNotes)
        
        #expect(creditCard.metadata.tagIds?.count == 1)
        let creditCardTagNames = Set(creditCard.metadata.tagIds?.compactMap { tagId in
            result.tags.first { $0.tagID == tagId }?.name
        } ?? [])
        #expect(creditCardTagNames == Set(["Test"]))
        
        #expect(creditCard.metadata.creationDate == Date(timeIntervalSince1970: 1765906569))
        #expect(creditCard.metadata.modificationDate == Date(timeIntervalSince1970: 1765906817))

        // MARK: Secure Note 1 - "Note"
        let secureNote = try #require(notes.first { $0.name == "Note" })
        #expect(secureNote.vaultId == testVaultID)
        
        #expect(secureNote.content.text != nil)
        let noteText = try #require(decrypt(secureNote.content.text))
        #expect(noteText == "Lorem ipsum notka")
        
        #expect(secureNote.content.additionalInfo == nil) // no fields
        
        #expect(secureNote.metadata.tagIds?.count == 1)
        let secureNoteTagNames = Set(secureNote.metadata.tagIds?.compactMap { tagId in
            result.tags.first { $0.tagID == tagId }?.name
        } ?? [])
        #expect(secureNoteTagNames == Set(["Erunestian"]))
        
        #expect(secureNote.metadata.creationDate == Date(timeIntervalSince1970: 1765907279))
        #expect(secureNote.metadata.modificationDate == Date(timeIntervalSince1970: 1765907279))

        // MARK: Secure Note 2 - "Bank account" (finance category -> secure note)
        let bankAccount = try #require(notes.first { $0.name?.contains("(Finance)") ?? false })
        #expect(bankAccount.name == "Bank account (Finance)")
        #expect(bankAccount.vaultId == testVaultID)
        #expect(bankAccount.content.text != nil)
        let expectedBankAccountText = """
            Bank name: Santander
            Account holder: Erunestian
            Account type: Oszczędnościowe
            Account number: 12345678909
            Transaction password: $v8?)}p(*}ygBx8wJ)_wW.QhK(wW!Y2o

            Notatka do banku
            """
        let bankAccountText = try #require(decrypt(bankAccount.content.text))
        #expect(bankAccountText == expectedBankAccountText)
        #expect(bankAccount.content.additionalInfo == nil)
        #expect(bankAccount.metadata.protectionLevel == .normal)
        #expect(bankAccount.metadata.trashedStatus == .no)
        #expect(bankAccount.metadata.tagIds == nil) // not in any folder

        #expect(bankAccount.metadata.creationDate == Date(timeIntervalSince1970: 1765907066))
        #expect(bankAccount.metadata.modificationDate == Date(timeIntervalSince1970: 1765978578))
    }

    // MARK: - Error Handling Tests

    @Test
    func invalidJSONThrowsWrongFormat() async {
        // GIVEN
        let invalidData = "not valid json".data(using: .utf8)!

        // WHEN/THEN
        await #expect(throws: ExternalServiceImportError.wrongFormat) {
            try await interactor.importService(.enpass, content: .file(invalidData))
        }
    }

    @Test
    func missingVaultThrowsWrongFormat() async throws {
        // GIVEN
        mockMainRepository.withSelectedVault(nil)
        let data = try loadEnpassTestData()

        // WHEN/THEN
        await #expect(throws: ExternalServiceImportError.wrongFormat) {
            try await interactor.importService(.enpass, content: .file(data))
        }
    }

    // MARK: - Helper Methods

    private func loadEnpassTestData() throws -> Data {
        guard let url = Bundle(for: MockMainRepository.self).url(forResource: "Enpass", withExtension: "json") else {
            throw TestError.resourceNotFound("Enpass.json test resource not found")
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
