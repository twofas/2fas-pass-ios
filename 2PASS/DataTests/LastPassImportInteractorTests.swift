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

@Suite("Import LastPass file")
struct LastPassImportInteractorTests {
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
    func importLastPassFile() async throws {
        // GIVEN
        mockPaymentCardUtilityInteractor
            .withDetectCardIssuer { _ in .mastercard }
            .withCardNumberMask { _ in "0719" }

        let data = try loadLastPassTestData()

        // WHEN
        let result = try await interactor.importService(.lastPass, content: .file(data))

        // THEN
        // The Lastpass.csv file contains:
        // - 3 credit cards
        // - 2 secure notes
        // - 1 login
        // - 1 address (converted to secure note)
        // - 1 bank account (converted to secure note)
        #expect(result.items.count == 8)
        #expect(result.tags.count == 2) // "Folder 1" and "Folder 2"
        #expect(result.itemsConvertedToSecureNotes == 2)

        // Verify item types
        let logins = result.items.filter { if case .login = $0 { return true } else { return false } }
        let cards = result.items.filter { if case .paymentCard = $0 { return true } else { return false } }
        let notes = result.items.filter { if case .secureNote = $0 { return true } else { return false } }

        #expect(logins.count == 1)
        #expect(cards.count == 3)
        #expect(notes.count == 4)
    }

    // MARK: - Login Import Tests

    @Test
    func importLoginItemFromLastPassFile() async throws {
        // GIVEN
        let data = try loadLastPassTestData()

        // WHEN
        let result = try await interactor.importService(.lastPass, content: .file(data))

        // THEN
        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let testLogin = try #require(logins.first { $0.name == "Hasło do eksportu" })
        #expect(testLogin.content.username == "Erunestian")
        let testLoginPassword = try #require(decrypt(testLogin.content.password))
        #expect(testLoginPassword == "zixxUs-dijnej-1rante")
        #expect(testLogin.content.uris?.first?.uri == "https://www.youtube.com/feed/subscriptions")
        #expect(testLogin.content.notes == "Lorem ipsum")
    }

    @Test
    func importLoginWithFolderTags() async throws {
        // GIVEN
        let data = try loadLastPassTestData()

        // WHEN
        let result = try await interactor.importService(.lastPass, content: .file(data))

        // THEN
        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let testLogin = try #require(logins.first { $0.name == "Hasło do eksportu" })
        // Should have 2 tags: "Folder 1" and "Folder 2"
        #expect(testLogin.metadata.tagIds?.count == 2)

        let tagNames = Set(testLogin.metadata.tagIds?.compactMap { tagId in
            result.tags.first { $0.tagID == tagId }?.name
        } ?? [])
        #expect(tagNames == Set(["Folder 1", "Folder 2"]))
    }

    // MARK: - Credit Card Import Tests

    @Test
    func importCreditCardItem() async throws {
        // GIVEN
        mockPaymentCardUtilityInteractor
            .withCardNumberMask { _ in "0719" }
            .withDetectCardIssuer { _ in .mastercard }

        let data = try loadLastPassTestData()

        // WHEN
        let result = try await interactor.importService(.lastPass, content: .file(data))

        // THEN
        let cards = result.items.compactMap { item -> PaymentCardItemData? in
            if case .paymentCard(let card) = item { return card }
            return nil
        }

        #expect(cards.count == 3)
        let creditCard = try #require(cards.first { $0.name == "Karta 1" })
        #expect(creditCard.content.cardHolder == "Karta 2FAS")

        let cardNumber = try #require(decrypt(creditCard.content.cardNumber))
        #expect(cardNumber == "5597599903700719")

        let securityCode = try #require(decrypt(creditCard.content.securityCode))
        #expect(securityCode == "824")

        let expirationDate = try #require(decrypt(creditCard.content.expirationDate))
        #expect(expirationDate == "11/30")

        #expect(creditCard.content.cardNumberMask == "0719")
        #expect(creditCard.content.cardIssuer == PaymentCardIssuer.mastercard.rawValue)
        let expectedNotes = """
            test

            Start Date: June,2024
            """
        #expect(creditCard.content.notes == expectedNotes)
    }

    // MARK: - Secure Note Import Tests

    @Test
    func importSecureNoteItem() async throws {
        // GIVEN
        let data = try loadLastPassTestData()

        // WHEN
        let result = try await interactor.importService(.lastPass, content: .file(data))

        // THEN
        let notes = result.items.compactMap { item -> SecureNoteItemData? in
            if case .secureNote(let note) = item { return note }
            return nil
        }

        let noteItem = try #require(notes.first { $0.name == "Notka 1" })
        let noteText = try #require(decrypt(noteItem.content.text))
        #expect(noteText == "Notka testowa")
    }

    @Test
    func importSecureNoteWithHTMLContent() async throws {
        // GIVEN
        let data = try loadLastPassTestData()

        // WHEN
        let result = try await interactor.importService(.lastPass, content: .file(data))

        // THEN
        let notes = result.items.compactMap { item -> SecureNoteItemData? in
            if case .secureNote(let note) = item { return note }
            return nil
        }

        let noteItem = notes.first { $0.name == "Notka 2" }
        #expect(noteItem != nil)
        // HTML content should be preserved
        let noteText = try #require(decrypt(noteItem?.content.text))
        let expectedHTMLNote = """
            <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Nisl tincidunt eget nullam non. Quis hendrerit dolor magna eget est lorem ipsum dolor sit. Volutpat odio facilisis mauris sit amet massa. Commodo odio aenean sed adipiscing diam donec adipiscing tristique. Mi eget mauris pharetra et. Non tellus orci ac auctor augue. Elit at imperdiet dui accumsan sit. Ornare arcu dui vivamus arcu felis. Egestas integer eget aliquet nibh praesent. In hac habitasse platea dictumst quisque sagittis purus. Pulvinar elementum integer enim neque volutpat ac.</p><p>Senectus et netus et malesuada. Nunc pulvinar sapien et ligula ullamcorper malesuada proin. Neque convallis a cras semper auctor. Libero id faucibus nisl tincidunt eget. Leo a diam sollicitudin tempor id. A lacus vestibulum sed arcu non odio euismod lacinia. In tellus integer feugiat scelerisque. Feugiat in fermentum posuere urna nec tincidunt praesent. Porttitor rhoncus dolor purus non enim praesent elementum facilisis. Nisi scelerisque eu ultrices vitae auctor eu augue ut lectus. Ipsum faucibus vitae aliquet nec ullamcorper sit amet risus. Et malesuada fames ac turpis egestas sed. Sit amet nisl suscipit adipiscing bibendum est ultricies. Arcu ac tortor dignissim convallis aenean et tortor at. Pretium viverra suspendisse potenti nullam ac tortor vitae purus. Eros donec ac odio tempor orci dapibus ultrices. Elementum nibh tellus molestie nunc. Et magnis dis parturient montes nascetur. Est placerat in egestas erat imperdiet. Consequat interdum varius sit amet mattis vulputate enim.</p><p>Sit amet nulla facilisi morbi tempus. Nulla facilisi cras fermentum odio eu. Etiam erat velit scelerisque in dictum non consectetur a erat. Enim nulla aliquet porttitor lacus luctus accumsan tortor posuere. Ut sem nulla pharetra diam. Fames ac turpis egestas maecenas. Bibendum neque egestas congue quisque egestas diam. Laoreet id donec ultrices tincidunt arcu non sodales neque. Eget felis eget nunc lobortis mattis aliquam faucibus purus. Faucibus interdum posuere lorem ipsum dolor sit.</p><p>Et netus et malesuada fames ac. Erat pellentesque adipiscing commodo elit at imperdiet dui accumsan. Sodales neque sodales ut etiam sit amet nisl purus in. Maecenas volutpat blandit aliquam etiam. Sit amet luctus venenatis lectus magna fringilla urna porttitor rhoncus. Egestas purus viverra accumsan in nisl. Semper feugiat nibh sed pulvinar proin. Duis convallis convallis tellus id interdum velit laoreet. Ante in nibh mauris cursus mattis molestie. Ut etiam sit amet nisl purus in mollis nunc. Feugiat sed lectus vestibulum mattis ullamcorper velit sed ullamcorper. Tellus at urna condimentum mattis pellentesque id nibh tortor id. Tristique magna sit amet purus gravida quis blandit turpis cursus. Dolor sit amet consectetur adipiscing. Consequat ac felis donec et odio pellentesque diam volutpat. Nunc sed augue lacus viverra vitae congue. Mauris in aliquam sem fringilla ut morbi tincidunt augue.</p>
            """
        #expect(noteText == expectedHTMLNote)
    }

    // MARK: - Address Import Tests

    @Test
    func importAddressAsSecureNote() async throws {
        // GIVEN
        let data = try loadLastPassTestData()

        // WHEN
        let result = try await interactor.importService(.lastPass, content: .file(data))

        // THEN
        #expect(result.itemsConvertedToSecureNotes >= 1)

        let notes = result.items.compactMap { item -> SecureNoteItemData? in
            if case .secureNote(let note) = item { return note }
            return nil
        }

        let addressNote = notes.first { $0.name?.contains("(Address)") ?? false }
        #expect(addressNote != nil)
        #expect(addressNote?.name == "Adres do eksportu (Address)")

        let noteText = try #require(decrypt(addressNote?.content.text))
        let expectedAddressText = """
            Address 1: Szara
            Address 2: Długa
            Address 3: Centralna
            Birthday: August,23,2000
            City / Town: Gliwice
            Company: 2FAS
            Country: PL
            County: Śląskie
            Email Address: 2fas@gmail.com
            Evening Phone: 44111222333 ext.12
            Fax: 994444555666 ext.14
            First Name: Arthur
            Gender: m
            Last Name: Morgan
            Middle Name: Joe
            Mobile Phone: 591777888999 ext.13
            Phone: 48404505606 ext.11
            State: Jakiś
            Timezone: +01:00,1
            Title: mr
            Username: Erunestian
            Zip / Postal Code: 40-789

            Notatka do eskportu
            """
        #expect(noteText == expectedAddressText)
    }

    // MARK: - Bank Account Import Tests

    @Test
    func importBankAccountAsSecureNote() async throws {
        // GIVEN
        let data = try loadLastPassTestData()

        // WHEN
        let result = try await interactor.importService(.lastPass, content: .file(data))

        // THEN
        let notes = result.items.compactMap { item -> SecureNoteItemData? in
            if case .secureNote(let note) = item { return note }
            return nil
        }

        let bankNote = notes.first { $0.name?.contains("(Bank Account)") ?? false }
        #expect(bankNote != nil)
        #expect(bankNote?.name == "Konto bankowe (Bank Account)")

        let noteText = try #require(decrypt(bankNote?.content.text))
        let expectedBankText = """
            Account Number: 12345678890987654321
            Account Type: Oszczędnościowe
            Bank Name: ING
            Branch Address: example@gmail.com
            Branch Phone: 109802304
            IBAN Number: 214344578799608007
            Pin: 1234
            Routing Number: 3583593
            SWIFT Code: INGB PL PW 908

            Konto bankowe do eskportu
            """
        #expect(noteText == expectedBankText)
    }

    // MARK: - Folder/Tag Import Tests

    @Test
    func importFoldersAsTags() async throws {
        // GIVEN
        let data = try loadLastPassTestData()

        // WHEN
        let result = try await interactor.importService(.lastPass, content: .file(data))

        // THEN
        #expect(result.tags.count == 2)

        let tagNames = result.tags.map { $0.name }
        #expect(tagNames.contains("Folder 1"))
        #expect(tagNames.contains("Folder 2"))
    }

    @Test
    func importItemWithSingleFolder() async throws {
        // GIVEN
        let data = try loadLastPassTestData()

        // WHEN
        let result = try await interactor.importService(.lastPass, content: .file(data))

        // THEN
        let notes = result.items.compactMap { item -> SecureNoteItemData? in
            if case .secureNote(let note) = item { return note }
            return nil
        }

        // "Notka 1" is in "Folder 1" only
        let noteItem = notes.first { $0.name == "Notka 1" }
        #expect(noteItem?.metadata.tagIds?.count == 1)

        let tagName = noteItem?.metadata.tagIds?.first.flatMap { tagId in
            result.tags.first { $0.tagID == tagId }?.name
        }
        #expect(tagName == "Folder 1")
    }

    // MARK: - Comprehensive Import Test

    @Test
    func importAllValuesFromLastPassFile() async throws {
        // GIVEN - Use real implementations
        let realPaymentCardUtilityInteractor = PaymentCardUtilityInteractor()
        let realURIInteractor = URIInteractor(mainRepository: mockMainRepository)
        let realInteractor = ExternalServiceImportInteractor(
            mainRepository: mockMainRepository,
            uriInteractor: realURIInteractor,
            paymentCardUtilityInteractor: realPaymentCardUtilityInteractor
        )

        let data = try loadLastPassTestData()

        // WHEN
        let result = try await realInteractor.importService(.lastPass, content: .file(data))

        // THEN - Verify result summary
        #expect(result.items.count == 8)
        #expect(result.tags.count == 2)
        #expect(result.itemsConvertedToSecureNotes == 2)

        // Extract items by type
        let logins = result.items.compactMap { if case .login(let l) = $0 { return l } else { return nil } }
        let cards = result.items.compactMap { if case .paymentCard(let c) = $0 { return c } else { return nil } }
        let notes = result.items.compactMap { if case .secureNote(let n) = $0 { return n } else { return nil } }

        #expect(logins.count == 1)
        #expect(cards.count == 3)
        #expect(notes.count == 4)

        // MARK: Tags (folders)
        let tagNames = Set(result.tags.map { $0.name })
        #expect(tagNames == Set(["Folder 1", "Folder 2"]))
        for tag in result.tags {
            #expect(tag.vaultID == testVaultID)
        }

        // MARK: Login - "Hasło do eksportu"
        let loginItem = try #require(logins.first { $0.name == "Hasło do eksportu" })
        #expect(loginItem.vaultId == testVaultID)
        #expect(loginItem.content.username == "Erunestian")

        let loginPassword = try #require(decrypt(loginItem.content.password))
        #expect(loginPassword == "zixxUs-dijnej-1rante")
        #expect(loginItem.content.uris?[0].uri == "https://www.youtube.com/feed/subscriptions")
        #expect(loginItem.content.uris?[0].match == .domain)
        #expect(loginItem.content.notes == "Lorem ipsum")
        #expect(loginItem.metadata.protectionLevel == .normal)
        #expect(loginItem.metadata.trashedStatus == .no)

        #expect(loginItem.metadata.tagIds?.count == 2)
        let loginTagNames = Set(loginItem.metadata.tagIds?.compactMap { tagId in
            result.tags.first { $0.tagID == tagId }?.name
        } ?? [])
        #expect(loginTagNames == Set(["Folder 1", "Folder 2"]))

        // MARK: Credit Card 1 - "Karta 1"
        let creditCard1 = try #require(cards.first { $0.name == "Karta 1" })
        #expect(creditCard1.vaultId == testVaultID)
        #expect(creditCard1.content.cardHolder == "Karta 2FAS")

        let cardNumber1 = try #require(decrypt(creditCard1.content.cardNumber))
        #expect(cardNumber1 == "5597599903700719")

        let securityCode1 = try #require(decrypt(creditCard1.content.securityCode))
        #expect(securityCode1 == "824")

        let expirationDate1 = try #require(decrypt(creditCard1.content.expirationDate))
        #expect(expirationDate1 == "11/30")

        #expect(creditCard1.content.cardNumberMask == "0719")
        #expect(creditCard1.content.cardIssuer == PaymentCardIssuer.mastercard.rawValue)

        // Notes should contain: original note + additional fields
        let expectedCard1Notes = """
            test

            Start Date: June,2024
            """
        #expect(creditCard1.content.notes == expectedCard1Notes)

        #expect(creditCard1.metadata.tagIds?.count == 2)
        let card1TagNames = Set(creditCard1.metadata.tagIds?.compactMap { tagId in
            result.tags.first { $0.tagID == tagId }?.name
        } ?? [])
        #expect(card1TagNames == Set(["Folder 1", "Folder 2"]))

        // MARK: Credit Card 3 - "Karta 3" (no folder)
        let creditCard3 = try #require(cards.first { $0.name == "Karta 3" })
        #expect(creditCard3.metadata.tagIds == nil) // not in any folder

        let cardNumber3 = try #require(decrypt(creditCard3.content.cardNumber))
        #expect(cardNumber3 == "3550020566961870")

        // Notes should contain the original note + additional fields
        let expectedCard3Notes = """
            Karta do eksportu

            Start Date: April,2022
            """
        #expect(creditCard3.content.notes == expectedCard3Notes)

        // MARK: Secure Note 1 - "Notka 1"
        let secureNote1 = try #require(notes.first { $0.name == "Notka 1" })
        #expect(secureNote1.vaultId == testVaultID)

        let noteText1 = try #require(decrypt(secureNote1.content.text))
        #expect(noteText1 == "Notka testowa")

        #expect(secureNote1.metadata.tagIds?.count == 1)
        let note1TagNames = Set(secureNote1.metadata.tagIds?.compactMap { tagId in
            result.tags.first { $0.tagID == tagId }?.name
        } ?? [])
        #expect(note1TagNames == Set(["Folder 1"]))

        // MARK: Secure Note 2 - "Notka 2" (HTML content)
        let secureNote2 = try #require(notes.first { $0.name == "Notka 2" })
        #expect(secureNote2.metadata.tagIds == nil) // not in any folder

        let noteText2 = try #require(decrypt(secureNote2.content.text))
        let expectedNote2Text = """
            <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Nisl tincidunt eget nullam non. Quis hendrerit dolor magna eget est lorem ipsum dolor sit. Volutpat odio facilisis mauris sit amet massa. Commodo odio aenean sed adipiscing diam donec adipiscing tristique. Mi eget mauris pharetra et. Non tellus orci ac auctor augue. Elit at imperdiet dui accumsan sit. Ornare arcu dui vivamus arcu felis. Egestas integer eget aliquet nibh praesent. In hac habitasse platea dictumst quisque sagittis purus. Pulvinar elementum integer enim neque volutpat ac.</p><p>Senectus et netus et malesuada. Nunc pulvinar sapien et ligula ullamcorper malesuada proin. Neque convallis a cras semper auctor. Libero id faucibus nisl tincidunt eget. Leo a diam sollicitudin tempor id. A lacus vestibulum sed arcu non odio euismod lacinia. In tellus integer feugiat scelerisque. Feugiat in fermentum posuere urna nec tincidunt praesent. Porttitor rhoncus dolor purus non enim praesent elementum facilisis. Nisi scelerisque eu ultrices vitae auctor eu augue ut lectus. Ipsum faucibus vitae aliquet nec ullamcorper sit amet risus. Et malesuada fames ac turpis egestas sed. Sit amet nisl suscipit adipiscing bibendum est ultricies. Arcu ac tortor dignissim convallis aenean et tortor at. Pretium viverra suspendisse potenti nullam ac tortor vitae purus. Eros donec ac odio tempor orci dapibus ultrices. Elementum nibh tellus molestie nunc. Et magnis dis parturient montes nascetur. Est placerat in egestas erat imperdiet. Consequat interdum varius sit amet mattis vulputate enim.</p><p>Sit amet nulla facilisi morbi tempus. Nulla facilisi cras fermentum odio eu. Etiam erat velit scelerisque in dictum non consectetur a erat. Enim nulla aliquet porttitor lacus luctus accumsan tortor posuere. Ut sem nulla pharetra diam. Fames ac turpis egestas maecenas. Bibendum neque egestas congue quisque egestas diam. Laoreet id donec ultrices tincidunt arcu non sodales neque. Eget felis eget nunc lobortis mattis aliquam faucibus purus. Faucibus interdum posuere lorem ipsum dolor sit.</p><p>Et netus et malesuada fames ac. Erat pellentesque adipiscing commodo elit at imperdiet dui accumsan. Sodales neque sodales ut etiam sit amet nisl purus in. Maecenas volutpat blandit aliquam etiam. Sit amet luctus venenatis lectus magna fringilla urna porttitor rhoncus. Egestas purus viverra accumsan in nisl. Semper feugiat nibh sed pulvinar proin. Duis convallis convallis tellus id interdum velit laoreet. Ante in nibh mauris cursus mattis molestie. Ut etiam sit amet nisl purus in mollis nunc. Feugiat sed lectus vestibulum mattis ullamcorper velit sed ullamcorper. Tellus at urna condimentum mattis pellentesque id nibh tortor id. Tristique magna sit amet purus gravida quis blandit turpis cursus. Dolor sit amet consectetur adipiscing. Consequat ac felis donec et odio pellentesque diam volutpat. Nunc sed augue lacus viverra vitae congue. Mauris in aliquam sem fringilla ut morbi tincidunt augue.</p>
            """
        #expect(noteText2 == expectedNote2Text)

        // MARK: Address - "Adres do eksportu (Address)"
        let addressNote = try #require(notes.first { $0.name?.contains("(Address)") ?? false })
        #expect(addressNote.name == "Adres do eksportu (Address)")
        #expect(addressNote.vaultId == testVaultID)

        let addressText = try #require(decrypt(addressNote.content.text))
        let expectedAddressText = """
            Address 1: Szara
            Address 2: Długa
            Address 3: Centralna
            Birthday: August,23,2000
            City / Town: Gliwice
            Company: 2FAS
            Country: PL
            County: Śląskie
            Email Address: 2fas@gmail.com
            Evening Phone: 44111222333 ext.12
            Fax: 994444555666 ext.14
            First Name: Arthur
            Gender: m
            Last Name: Morgan
            Middle Name: Joe
            Mobile Phone: 591777888999 ext.13
            Phone: 48404505606 ext.11
            State: Jakiś
            Timezone: +01:00,1
            Title: mr
            Username: Erunestian
            Zip / Postal Code: 40-789

            Notatka do eskportu
            """
        #expect(addressText == expectedAddressText)

        // MARK: Bank Account - "Konto bankowe (Bank Account)"
        let bankNote = try #require(notes.first { $0.name?.contains("(Bank Account)") ?? false })
        #expect(bankNote.name == "Konto bankowe (Bank Account)")
        #expect(bankNote.vaultId == testVaultID)

        let bankText = try #require(decrypt(bankNote.content.text))
        let expectedBankText = """
            Account Number: 12345678890987654321
            Account Type: Oszczędnościowe
            Bank Name: ING
            Branch Address: example@gmail.com
            Branch Phone: 109802304
            IBAN Number: 214344578799608007
            Pin: 1234
            Routing Number: 3583593
            SWIFT Code: INGB PL PW 908

            Konto bankowe do eskportu
            """
        #expect(bankText == expectedBankText)
    }

    // MARK: - Error Handling Tests

    @Test
    func invalidCSVThrowsWrongFormat() async {
        // GIVEN
        let invalidData = "not,valid,csv,without,proper,headers".data(using: .utf8)!

        // WHEN/THEN
        await #expect(throws: ExternalServiceImportError.wrongFormat) {
            try await interactor.importService(.lastPass, content: .file(invalidData))
        }
    }

    @Test
    func missingVaultThrowsWrongFormat() async throws {
        // GIVEN
        mockMainRepository.withSelectedVault(nil)
        let data = try loadLastPassTestData()

        // WHEN/THEN
        await #expect(throws: ExternalServiceImportError.wrongFormat) {
            try await interactor.importService(.lastPass, content: .file(data))
        }
    }

    @Test
    func emptyCSVWithHeadersReturnsEmptyResult() async throws {
        // GIVEN
        let csvData = "url,username,password,totp,extra,name,grouping,fav\n".data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.lastPass, content: .file(csvData))

        // THEN
        #expect(result.items.isEmpty)
        #expect(result.tags.isEmpty)
        #expect(result.itemsConvertedToSecureNotes == 0)
    }

    // MARK: - Helper Methods

    private func loadLastPassTestData() throws -> Data {
        guard let url = Bundle(for: MockMainRepository.self).url(forResource: "Lastpass", withExtension: "csv") else {
            throw TestError.resourceNotFound("Lastpass.csv test resource not found")
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
