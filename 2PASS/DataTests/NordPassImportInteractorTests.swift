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

@Suite("Import NordPass file - Unit Tests")
struct NordPassImportInteractorTests {
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

    // MARK: - Error Handling Tests

    @Test
    func invalidCSVThrowsWrongFormat() async {
        // GIVEN
        let invalidData = "not,valid,csv,without,proper,headers".data(using: .utf8)!

        // WHEN/THEN
        await #expect(throws: ExternalServiceImportError.wrongFormat) {
            try await interactor.importService(.nordPass, content: .file(invalidData))
        }
    }

    @Test
    func missingVaultThrowsWrongFormat() async throws {
        // GIVEN
        mockMainRepository.withSelectedVault(nil)
        let data = try loadNordPassTestData()

        // WHEN/THEN
        await #expect(throws: ExternalServiceImportError.wrongFormat) {
            try await interactor.importService(.nordPass, content: .file(data))
        }
    }

    @Test
    func emptyCSVWithHeadersReturnsEmptyResult() async throws {
        // GIVEN
        let csvData = "name,type,url,username,password\n".data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.nordPass, content: .file(csvData))

        // THEN
        #expect(result.items.isEmpty)
        #expect(result.tags.isEmpty)
        #expect(result.itemsConvertedToSecureNotes == 0)
    }

    @Test
    func missingRequiredColumnsThrowsWrongFormat() async {
        // GIVEN - CSV without "name" and "type" columns
        let csvData = "url,username,password\nhttps://example.com,user,pass\n".data(using: .utf8)!

        // WHEN/THEN
        await #expect(throws: ExternalServiceImportError.wrongFormat) {
            try await interactor.importService(.nordPass, content: .file(csvData))
        }
    }

    // MARK: - Helper Methods

    private func loadNordPassTestData() throws -> Data {
        guard let url = Bundle(for: MockMainRepository.self).url(forResource: "NordPass", withExtension: "csv") else {
            throw TestError.resourceNotFound("NordPass.csv test resource not found")
        }
        return try Data(contentsOf: url)
    }
}

// MARK: - Integration Tests

extension NordPassImportInteractorTests {

    @Suite("Import NordPass test file - comprehensive verification")
    struct IntegrationTests {

        private let mockMainRepository = MockMainRepository.defaultConfiguration()
        private let paymentCardUtilityInteractor = PaymentCardUtilityInteractor()
        private let uriInteractor: URIInteractor

        init() {
            self.uriInteractor = URIInteractor(mainRepository: mockMainRepository)
        }

        @Test
        func importNordPassCSV() async throws {
            let interactor = ExternalServiceImportInteractor(
                mainRepository: mockMainRepository,
                uriInteractor: uriInteractor,
                paymentCardUtilityInteractor: paymentCardUtilityInteractor
            )

            let data = try loadNordPassTestData()

            // WHEN
            let result = try await interactor.importService(.nordPass, content: .file(data))

            // THEN - Verify result summary
            // 2 logins + 1 credit card + 1 secure note + 1 identity (→ note) + 4 documents (→ notes) = 9 items
            // 3 folder rows are skipped
            #expect(result.items.count == 9)
            #expect(result.tags.count == 3)
            #expect(result.itemsConvertedToSecureNotes == 5) // 1 identity + 4 documents

            // Verify tags
            let tagNames = Set(result.tags.map(\.name))
            #expect(tagNames == Set(["Folder 1", "Folder 2", "Folder 3"]))

            // Create tag name to ID mapping for verification
            let tagNameToId = Dictionary(uniqueKeysWithValues: result.tags.map { ($0.name, $0.tagID) })

            // Verify all tags have correct vault ID
            for tag in result.tags {
                #expect(tag.vaultID == mockMainRepository.selectedVault?.vaultID)
            }

            // Extract items by type
            let logins = result.items.compactMap { if case .login(let l) = $0 { return l } else { return nil } }
            let cards = result.items.compactMap { if case .paymentCard(let c) = $0 { return c } else { return nil } }
            let notes = result.items.compactMap { if case .secureNote(let n) = $0 { return n } else { return nil } }

            #expect(logins.count == 2)
            #expect(cards.count == 1)
            #expect(notes.count == 6) // 1 regular note + 1 identity + 4 documents

            // MARK: Login #1 - "Login dla Maćka"
            let loginMacka = try #require(logins.first { $0.name == "Login dla Maćka" })
            #expect(loginMacka.vaultId == mockMainRepository.selectedVault?.vaultID)
            #expect(loginMacka.content.username == "Rafael")

            let loginMackaPassword = try #require(decrypt(loginMacka.content.password))
            #expect(loginMackaPassword == "UXcDQuZuE9ohNoWAgnFi")

            #expect(loginMacka.content.uris?.count == 1)
            #expect(loginMacka.content.uris?[0].uri == "2fas.com")
            #expect(loginMacka.content.uris?[0].match == .domain)

            #expect(loginMacka.metadata.protectionLevel == .normal)
            #expect(loginMacka.metadata.trashedStatus == .no)
            #expect(loginMacka.metadata.creationDate == Date.importPasswordPlaceholder)
            #expect(loginMacka.metadata.modificationDate == Date.importPasswordPlaceholder)

            // No folder = no tags
            #expect(loginMacka.metadata.tagIds == nil)

            // Notes should contain original note + custom field
            let expectedLoginMackaNotes = """
                Login z wieloma tagami

                Tags: 3 tag, Rafael, Starter Kit
                """
            #expect(loginMacka.content.notes == expectedLoginMackaNotes)

            // MARK: Login #2 - "Password"
            let passwordLogin = try #require(logins.first { $0.name == "Password" })
            #expect(passwordLogin.vaultId == mockMainRepository.selectedVault?.vaultID)
            #expect(passwordLogin.content.username == "rafols")

            let passwordLoginPassword = try #require(decrypt(passwordLogin.content.password))
            #expect(passwordLoginPassword == "y8gL676v7iyNrQWL7shE")

            // Primary URL + 2 additional URLs from JSON array
            #expect(passwordLogin.content.uris?.count == 3)
            #expect(passwordLogin.content.uris?[0].uri == "https://2fas.com")
            #expect(passwordLogin.content.uris?[0].match == .domain)
            #expect(passwordLogin.content.uris?[1].uri == "https://www.youtube.com")
            #expect(passwordLogin.content.uris?[1].match == .domain)
            #expect(passwordLogin.content.uris?[2].uri == "https://www.nexusmods.com")
            #expect(passwordLogin.content.uris?[2].match == .domain)

            #expect(passwordLogin.metadata.tagIds?.count == 1)
            #expect(passwordLogin.metadata.tagIds?.contains(tagNameToId["Folder 1"]!) == true)

            // Notes with custom fields (date field formatted by DateFormatter)
            // The date 1772150400 = Feb 27, 2026
            let passwordNotes = try #require(passwordLogin.content.notes)
            #expect(passwordNotes.hasPrefix("Notka password\n\nPole tekstowe 1: Rafael\nPole tekstowe 2 - data: "))
            // Date formatting is locale-dependent, so just check it contains the year
            #expect(passwordNotes.contains("2026"))

            // MARK: Credit Card - "Karta kredytowa Nordpass"
            let creditCard = try #require(cards.first { $0.name == "Karta kredytowa Nordpass" })
            #expect(creditCard.vaultId == mockMainRepository.selectedVault?.vaultID)
            #expect(creditCard.content.cardHolder == "Rafael")

            let cardNumber = try #require(decrypt(creditCard.content.cardNumber))
            #expect(cardNumber == "6739428148934312")

            let securityCode = try #require(decrypt(creditCard.content.securityCode))
            #expect(securityCode == "420")

            let expirationDate = try #require(decrypt(creditCard.content.expirationDate))
            #expect(expirationDate == "12/30")

            #expect(creditCard.content.cardNumberMask == "4312")
            // Card number starting with 6739 is Maestro
            #expect(creditCard.content.cardIssuer == nil)

            #expect(creditCard.metadata.protectionLevel == .normal)
            #expect(creditCard.metadata.trashedStatus == .no)

            // No folder = no tags
            #expect(creditCard.metadata.tagIds == nil)

            // Notes should contain: original note + PIN + zipcode + custom field
            let expectedCreditCardNotes = """
                Notatka do karty kredytowej

                PIN: 1234
                Zip Code: 40-503
                
                Pole tekstowe karta: Nie wiem
                """
            #expect(creditCard.content.notes == expectedCreditCardNotes)

            // MARK: Secure Note - "Bezpieczna notatka"
            let secureNote = try #require(notes.first { $0.name == "Bezpieczna notatka" })
            #expect(secureNote.vaultId == mockMainRepository.selectedVault?.vaultID)

            let noteText = try #require(decrypt(secureNote.content.text))
            #expect(noteText == "Notatka Nordpassowa")

            #expect(secureNote.metadata.protectionLevel == .normal)
            #expect(secureNote.metadata.trashedStatus == .no)

            #expect(secureNote.metadata.tagIds?.count == 1)
            #expect(secureNote.metadata.tagIds?.contains(tagNameToId["Folder 2"]!) == true)

            // Custom field goes to additionalInfo (not merged with text)
            #expect(secureNote.content.additionalInfo == "Pole tekstowe notatka: Jolo")

            // MARK: Identity (converted to Secure Note) - "Moje dane kontaktowe (Identity)"
            let identityNote = try #require(notes.first { $0.name == "Moje dane kontaktowe (Identity)" })
            #expect(identityNote.vaultId == mockMainRepository.selectedVault?.vaultID)

            let identityText = try #require(decrypt(identityNote.content.text))
            // Verify all identity fields are present (formatDictionary capitalizes first letter, replaces _ with space)
            let expectedIdentityText = """
                Address 1: Szara 13
                Address 2: Długa 5
                City: Gliwice
                Country: Poland
                Email: 2fas@gmail.com
                Full name: Erunestian
                Phone number: 409508607
                State: Śląskie
                Zipcode: 40-809

                Tekst do kontakty: whatever fits

                Notatka do kontaktu
                """
            #expect(identityText == expectedIdentityText)

            #expect(identityNote.metadata.protectionLevel == .normal)
            #expect(identityNote.metadata.tagIds?.count == 1)
            #expect(identityNote.metadata.tagIds?.contains(tagNameToId["Folder 3"]!) == true)

            // MARK: Document #1 (converted to Secure Note) - "Tożsamość (Document)"
            let docTozsamosc = try #require(notes.first { $0.name == "Tożsamość (Document)" })
            #expect(docTozsamosc.vaultId == mockMainRepository.selectedVault?.vaultID)

            let docTozsamoscText = try #require(decrypt(docTozsamosc.content.text))
            // Document has no identity fields, only custom field (hidden type) + note
            let expectedDocTozsamoscText = """
                Ukryty tekst: Sono stelte

                Notatka ID
                """
            #expect(docTozsamoscText == expectedDocTozsamoscText)

            #expect(docTozsamosc.metadata.protectionLevel == .normal)
            #expect(docTozsamosc.metadata.tagIds?.count == 1)
            #expect(docTozsamosc.metadata.tagIds?.contains(tagNameToId["Folder 1"]!) == true)

            // MARK: Document #2 (converted to Secure Note) - "Prawko (Document)"
            let docPrawko = try #require(notes.first { $0.name == "Prawko (Document)" })
            #expect(docPrawko.vaultId == mockMainRepository.selectedVault?.vaultID)

            let docPrawkoText = try #require(decrypt(docPrawko.content.text))
            #expect(docPrawkoText == "Notatka do prawka")

            #expect(docPrawko.metadata.tagIds?.count == 1)
            #expect(docPrawko.metadata.tagIds?.contains(tagNameToId["Folder 2"]!) == true)

            // MARK: Document #3 (converted to Secure Note) - "Paszport (Document)"
            let docPaszport = try #require(notes.first { $0.name == "Paszport (Document)" })
            #expect(docPaszport.vaultId == mockMainRepository.selectedVault?.vaultID)

            let docPaszportText = try #require(decrypt(docPaszport.content.text))
            #expect(docPaszportText == "Notatka do paszportu")

            #expect(docPaszport.metadata.tagIds?.count == 1)
            #expect(docPaszport.metadata.tagIds?.contains(tagNameToId["Folder 3"]!) == true)

            // MARK: Document #4 (converted to Secure Note) - "Randomowy dokument (Document)"
            let docRandom = try #require(notes.first { $0.name == "Randomowy dokument (Document)" })
            #expect(docRandom.vaultId == mockMainRepository.selectedVault?.vaultID)

            let docRandomText = try #require(decrypt(docRandom.content.text))
            #expect(docRandomText == "Coś")

            // No folder = no tags
            #expect(docRandom.metadata.tagIds == nil)

            // MARK: Verify folder rows are skipped
            let allItemNames = result.items.map { item -> String? in
                switch item {
                case .login(let l): return l.name
                case .paymentCard(let p): return p.name
                case .secureNote(let s): return s.name
                case .raw(let r): return r.name
                }
            }
            // Folder definition rows should not create items
            #expect(!allItemNames.contains("Folder 1"))
            #expect(!allItemNames.contains("Folder 2"))
            #expect(!allItemNames.contains("Folder 3"))
        }

        // MARK: - Helper Methods

        private func loadNordPassTestData() throws -> Data {
            guard let url = Bundle(for: MockMainRepository.self).url(forResource: "NordPass", withExtension: "csv") else {
                throw TestError.resourceNotFound("NordPass.csv test resource not found")
            }
            return try Data(contentsOf: url)
        }

        private func decrypt(_ data: Data?) -> String? {
            DataTests.decrypt(data, using: mockMainRepository)
        }
    }
}
