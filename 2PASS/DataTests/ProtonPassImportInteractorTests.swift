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

@Suite("Import ProtonPass file")
struct ProtonPassImportInteractorTests {
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
    func importProtonPassZIPFile() async throws {
        // GIVEN
        let data = try loadProtonPassTestData()

        // WHEN
        let result = try await interactor.importService(.protonPass, content: .file(data))

        // THEN
        // The ProtonPass.zip contains:
        // - 2 login items
        // - 2 credit cards
        // - 1 secure note
        // - 1 wifi
        // - 11 items converted to secure notes (1 identity + 9 custom + 1 sshKey)
        let logins = result.items.filter { if case .login = $0 { return true } else { return false } }
        let cards = result.items.filter { if case .paymentCard = $0 { return true } else { return false } }
        let notes = result.items.filter { if case .secureNote = $0 { return true } else { return false } }
        let wifis = result.items.filter { if case .wifi = $0 { return true } else { return false } }

        #expect(logins.count == 2)
        #expect(cards.count == 2)
        #expect(notes.count == 12) // 1 native + 11 converted
        #expect(wifis.count == 1)
        #expect(result.tags.isEmpty)
        #expect(result.itemsConvertedToSecureNotes == 11)
    }

    // MARK: - Login Import Tests

    @Test
    func importLoginItemWithUsername() async throws {
        // GIVEN
        let data = try loadProtonPassTestData()

        // WHEN
        let result = try await interactor.importService(.protonPass, content: .file(data))

        // THEN
        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let login = try #require(logins.first { $0.name == "wellcome-home.com" })
        #expect(login.content.username == "mark")

        let password = try #require(decrypt(login.content.password))
        #expect(password == "Washout2-Professor5-Antibody1-Lustfully9-Barrel5")

        #expect(login.content.uris?.first?.uri == "https://wellcome-home.com")
        #expect(login.content.uris?.first?.match == .domain)
        #expect(login.vaultId == testVaultID)
        #expect(login.metadata.protectionLevel == .normal)
        #expect(login.metadata.trashedStatus == .no)
    }

    @Test
    func importLoginItemWithEmailAsUsername() async throws {
        // GIVEN
        let data = try loadProtonPassTestData()

        // WHEN
        let result = try await interactor.importService(.protonPass, content: .file(data))

        // THEN
        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        // This login has empty username but has email
        let login = try #require(logins.first { $0.name == "Przykład tytuł Login" })
        #expect(login.content.username == "simon@kac.vegas")

        let password = try #require(decrypt(login.content.password))
        #expect(password == "Tarnish9-Green2-Scanner8-Unretired9-Operable7")

        #expect(login.content.uris?.first?.uri == "https://onet.com")
        #expect(login.content.notes == "Notatka do login\n\nVault: Personal")
    }

    // MARK: - Credit Card Import Tests

    @Test
    func importCreditCardItem() async throws {
        // GIVEN
        mockPaymentCardUtilityInteractor
            .withCardNumberMask { _ in "1238" }
            .withDetectCardIssuer { _ in nil }

        let data = try loadProtonPassTestData()

        // WHEN
        let result = try await interactor.importService(.protonPass, content: .file(data))

        // THEN
        let cards = result.items.compactMap { item -> PaymentCardItemData? in
            if case .paymentCard(let card) = item { return card }
            return nil
        }

        let card = try #require(cards.first { $0.name == "Karta 1238" })
        #expect(card.content.cardHolder == "Simon H Bron")

        let cardNumber = try #require(decrypt(card.content.cardNumber))
        #expect(cardNumber == "1234123413241238")

        let securityCode = try #require(decrypt(card.content.securityCode))
        #expect(securityCode == "810")

        let expirationDate = try #require(decrypt(card.content.expirationDate))
        #expect(expirationDate == "10/30")

        let notes = try #require(card.content.notes)
        #expect(notes == "Note to card\n\nPin: 111111\n\nVault: Personal")

        #expect(card.vaultId == testVaultID)
        #expect(card.metadata.protectionLevel == .normal)
    }

    @Test
    func importCreditCardWithExpiredDate() async throws {
        // GIVEN
        let data = try loadProtonPassTestData()

        // WHEN
        let result = try await interactor.importService(.protonPass, content: .file(data))

        // THEN
        let cards = result.items.compactMap { item -> PaymentCardItemData? in
            if case .paymentCard(let card) = item { return card }
            return nil
        }

        let card = try #require(cards.first { $0.name == "Karta 2" })
        #expect(card.content.cardHolder == "Marek Hodler")

        let expirationDate = try #require(decrypt(card.content.expirationDate))
        #expect(expirationDate == "12/18")

        let notes = try #require(card.content.notes)
        #expect(notes == "Ktoś do karty dopisał notatkę\n\nPin: 1234\n\nVault: Personal")
    }

    // MARK: - Secure Note Import Tests

    @Test
    func importSecureNoteItem() async throws {
        // GIVEN
        let data = try loadProtonPassTestData()

        // WHEN
        let result = try await interactor.importService(.protonPass, content: .file(data))

        // THEN
        let notes = result.items.compactMap { item -> SecureNoteItemData? in
            if case .secureNote(let note) = item { return note }
            return nil
        }

        // Native secure note (not converted)
        let note = try #require(notes.first { $0.name == "Sekure Notę" })
        let text = try #require(decrypt(note.content.text))
        #expect(text == "Trudny język Polski język jest być")
        #expect(note.content.additionalInfo == "Vault: Personal")

        #expect(note.vaultId == testVaultID)
        #expect(note.metadata.protectionLevel == .normal)
    }

    // MARK: - Identity Conversion Tests

    @Test
    func importIdentityAsSecureNote() async throws {
        // GIVEN
        let data = try loadProtonPassTestData()

        // WHEN
        let result = try await interactor.importService(.protonPass, content: .file(data))

        // THEN
        let notes = result.items.compactMap { item -> SecureNoteItemData? in
            if case .secureNote(let note) = item { return note }
            return nil
        }

        let identityNote = try #require(notes.first { $0.name == "Paszport z Israela (Identity)" })

        let text = try #require(decrypt(identityNote.content.text))
        // formatDictionary sorts alphabetically and formats camelCase to Title Case
        let expectedText = """
            City: Miasto W Izraelu
            Country Or Region: Israel
            Email: jan@goldstein.com
            Full Name: Jan Goldstein
            License Number: NR LICENCJI\(" ")
            Organization: Nso
            Passport Number: NR PASZPORTU
            Phone Number: 5642534141
            Second Phone Number: 451245124812
            Social Security Number: SOCIAL NUMBER TUTAJ
            State Or Province: Stan Wyjatkowy
            Street Address: Ani Okresu Ani Adresu
            Website: storna www! po cholere nie wiem
            X Handle: adrss do twitera
            Zip Or Postal Code: 112112

            Vault: Personal
            """
        #expect(text == expectedText)
    }

    // MARK: - Custom Item Conversion Tests

    @Test
    func importCustomItemWithExtraFieldsAsSecureNote() async throws {
        // GIVEN
        let data = try loadProtonPassTestData()

        // WHEN
        let result = try await interactor.importService(.protonPass, content: .file(data))

        // THEN
        let notes = result.items.compactMap { item -> SecureNoteItemData? in
            if case .secureNote(let note) = item { return note }
            return nil
        }

        // API custom item - extraFields only (content.sections is empty)
        let apiNote = try #require(notes.first { $0.name == "API tytuł (Custom)" })
        let apiText = try #require(decrypt(apiNote.content.text))
        let expectedApiText = """
            API key: Klucz do api
            Secret: Sekretny klucz
            Expiry date: 2025-12-18
            Permissions: Permission jakiś

            Notatka

            Vault: Personal
            """
        #expect(apiText == expectedApiText)

        // Database custom item
        let dbNote = try #require(notes.first { $0.name == "Baza danych tytuł (Custom)" })
        let dbText = try #require(decrypt(dbNote.content.text))
        let expectedDbText = """
            Host: Host
            Port: 2222
            Username: Mój user
            Password: Hasało
            Database type: Typ bazy piszą

            Notatka

            Vault: Personal
            """
        #expect(dbText == expectedDbText)
    }

    // MARK: - SSH Key Conversion Tests

    @Test
    func importSSHKeyAsSecureNote() async throws {
        // GIVEN
        let data = try loadProtonPassTestData()

        // WHEN
        let result = try await interactor.importService(.protonPass, content: .file(data))

        // THEN
        let notes = result.items.compactMap { item -> SecureNoteItemData? in
            if case .secureNote(let note) = item { return note }
            return nil
        }

        let sshNote = try #require(notes.first { $0.name == "Klucz ssh (SshKey)" })

        let text = try #require(decrypt(sshNote.content.text))
        // formatDictionary output (sorted alphabetically) + extraFields + metadata note
        let expectedText = """
            Private Key: prywatny\(" ")
            Public Key: fdzjxjdj public

            Username: Simon
            Host: Host
            Note: Notka w środku

            Notę jak zwykle

            Vault: Personal
            """
        #expect(text == expectedText)
    }

    // MARK: - WiFi Import Tests

    @Test
    func importWiFiItem() async throws {
        // GIVEN
        let data = try loadProtonPassTestData()

        // WHEN
        let result = try await interactor.importService(.protonPass, content: .file(data))

        // THEN
        let wifis = result.items.compactMap { item -> WiFiItemData? in
            if case .wifi(let wifi) = item { return wifi }
            return nil
        }

        let wifi = try #require(wifis.first { $0.name == "Moje WiFi" })
        #expect(wifi.content.ssid == "defcon")
        #expect(wifi.content.securityType == .wpa2)
        #expect(wifi.content.hidden == false)
        #expect(wifi.vaultId == testVaultID)
        #expect(wifi.metadata.protectionLevel == .normal)

        let password = try #require(decrypt(wifi.content.password))
        #expect(password == "haslo111")

        let notes = try #require(wifi.content.notes)
        #expect(notes == "Note: Notka\n\nTa normalna\n\nVault: Personal")
    }

    // MARK: - Comprehensive Import Test

    @Test
    func importAllValuesFromProtonPassFile() async throws {
        // GIVEN - Use real implementations
        let realPaymentCardUtilityInteractor = PaymentCardUtilityInteractor()
        let realURIInteractor = URIInteractor(mainRepository: mockMainRepository)
        let realInteractor = ExternalServiceImportInteractor(
            mainRepository: mockMainRepository,
            uriInteractor: realURIInteractor,
            paymentCardUtilityInteractor: realPaymentCardUtilityInteractor
        )

        let data = try loadProtonPassTestData()

        // WHEN
        let result = try await realInteractor.importService(.protonPass, content: .file(data))

        // THEN - Verify result summary
        #expect(result.items.count == 17)
        #expect(result.tags.isEmpty)
        #expect(result.itemsConvertedToSecureNotes == 11)

        // Extract items by type
        let logins = result.items.compactMap { if case .login(let l) = $0 { return l } else { return nil } }
        let cards = result.items.compactMap { if case .paymentCard(let c) = $0 { return c } else { return nil } }
        let notes = result.items.compactMap { if case .secureNote(let n) = $0 { return n } else { return nil } }
        let wifis = result.items.compactMap { if case .wifi(let w) = $0 { return w } else { return nil } }

        #expect(logins.count == 2)
        #expect(cards.count == 2)
        #expect(notes.count == 12)
        #expect(wifis.count == 1)

        // MARK: Login 1 - "wellcome-home.com"
        let welcomeLogin = try #require(logins.first { $0.name == "wellcome-home.com" })
        #expect(welcomeLogin.vaultId == testVaultID)
        #expect(welcomeLogin.content.username == "mark")
        let welcomePassword = try #require(decrypt(welcomeLogin.content.password))
        #expect(welcomePassword == "Washout2-Professor5-Antibody1-Lustfully9-Barrel5")
        #expect(welcomeLogin.content.uris?[0].uri == "https://wellcome-home.com")
        #expect(welcomeLogin.content.uris?[0].match == .domain)
        #expect(welcomeLogin.content.notes == "Vault: Personal")
        #expect(welcomeLogin.metadata.protectionLevel == .normal)
        #expect(welcomeLogin.metadata.trashedStatus == .no)
        #expect(welcomeLogin.metadata.tagIds == nil)
        #expect(welcomeLogin.metadata.creationDate == Date(timeIntervalSince1970: 1740854486))
        #expect(welcomeLogin.metadata.modificationDate == Date(timeIntervalSince1970: 1740854486))

        // MARK: Login 2 - "Przykład tytuł Login"
        let przykladLogin = try #require(logins.first { $0.name == "Przykład tytuł Login" })
        #expect(przykladLogin.content.username == "simon@kac.vegas")
        let przykladPassword = try #require(decrypt(przykladLogin.content.password))
        #expect(przykladPassword == "Tarnish9-Green2-Scanner8-Unretired9-Operable7")
        #expect(przykladLogin.content.uris?[0].uri == "https://onet.com")
        #expect(przykladLogin.content.notes == "Notatka do login\n\nVault: Personal")
        #expect(przykladLogin.metadata.creationDate == Date(timeIntervalSince1970: 1766050424))
        #expect(przykladLogin.metadata.modificationDate == Date(timeIntervalSince1970: 1766050424))

        // MARK: Credit Card 1 - "Karta 1238"
        let karta1238 = try #require(cards.first { $0.name == "Karta 1238" })
        #expect(karta1238.vaultId == testVaultID)
        #expect(karta1238.content.cardHolder == "Simon H Bron")
        let karta1238Number = try #require(decrypt(karta1238.content.cardNumber))
        #expect(karta1238Number == "1234123413241238")
        let karta1238CVV = try #require(decrypt(karta1238.content.securityCode))
        #expect(karta1238CVV == "810")
        let karta1238Exp = try #require(decrypt(karta1238.content.expirationDate))
        #expect(karta1238Exp == "10/30")
        let karta1238Notes = try #require(karta1238.content.notes)
        #expect(karta1238Notes == "Note to card\n\nPin: 111111\n\nVault: Personal")
        #expect(karta1238.metadata.creationDate == Date(timeIntervalSince1970: 1764445742))

        // MARK: Credit Card 2 - "Karta 2"
        let karta2 = try #require(cards.first { $0.name == "Karta 2" })
        #expect(karta2.content.cardHolder == "Marek Hodler")
        let karta2Number = try #require(decrypt(karta2.content.cardNumber))
        #expect(karta2Number == "1234514545151848")
        let karta2CVV = try #require(decrypt(karta2.content.securityCode))
        #expect(karta2CVV == "555")
        let karta2Exp = try #require(decrypt(karta2.content.expirationDate))
        #expect(karta2Exp == "12/18")
        let karta2Notes = try #require(karta2.content.notes)
        #expect(karta2Notes == "Ktoś do karty dopisał notatkę\n\nPin: 1234\n\nVault: Personal")

        // MARK: Secure Note - "Sekure Notę"
        let secureNote = try #require(notes.first { $0.name == "Sekure Notę" })
        #expect(secureNote.vaultId == testVaultID)
        let secureNoteText = try #require(decrypt(secureNote.content.text))
        #expect(secureNoteText == "Trudny język Polski język jest być")
        #expect(secureNote.content.additionalInfo == "Vault: Personal")
        #expect(secureNote.metadata.creationDate == Date(timeIntervalSince1970: 1766050464))

        // MARK: Identity -> Secure Note - "Paszport z Israela"
        let identity = try #require(notes.first { $0.name == "Paszport z Israela (Identity)" })
        let identityText = try #require(decrypt(identity.content.text))
        let expectedIdentityText = """
            City: Miasto W Izraelu
            Country Or Region: Israel
            Email: jan@goldstein.com
            Full Name: Jan Goldstein
            License Number: NR LICENCJI\(" ")
            Organization: Nso
            Passport Number: NR PASZPORTU
            Phone Number: 5642534141
            Second Phone Number: 451245124812
            Social Security Number: SOCIAL NUMBER TUTAJ
            State Or Province: Stan Wyjatkowy
            Street Address: Ani Okresu Ani Adresu
            Website: storna www! po cholere nie wiem
            X Handle: adrss do twitera
            Zip Or Postal Code: 112112

            Vault: Personal
            """
        #expect(identityText == expectedIdentityText)

        // MARK: WiFi - "Moje WiFi"
        let wifi = try #require(wifis.first { $0.name == "Moje WiFi" })
        #expect(wifi.content.ssid == "defcon")
        #expect(wifi.content.securityType == .wpa2)
        #expect(wifi.content.hidden == false)
        #expect(wifi.vaultId == testVaultID)
        let wifiPassword = try #require(decrypt(wifi.content.password))
        #expect(wifiPassword == "haslo111")
        let wifiNotes = try #require(wifi.content.notes)
        #expect(wifiNotes == "Note: Notka\n\nTa normalna\n\nVault: Personal")
        #expect(wifi.metadata.creationDate == Date(timeIntervalSince1970: 1766050974))

        // MARK: SSH Key -> Secure Note - "Klucz ssh"
        let sshKey = try #require(notes.first { $0.name == "Klucz ssh (SshKey)" })
        let sshKeyText = try #require(decrypt(sshKey.content.text))
        let expectedSshText = """
            Private Key: prywatny\(" ")
            Public Key: fdzjxjdj public

            Username: Simon
            Host: Host
            Note: Notka w środku

            Notę jak zwykle

            Vault: Personal
            """
        #expect(sshKeyText == expectedSshText)
    }

    // MARK: - Timestamp Tests

    @Test
    func importItemsWithCorrectTimestamps() async throws {
        // GIVEN
        let data = try loadProtonPassTestData()

        // WHEN
        let result = try await interactor.importService(.protonPass, content: .file(data))

        // THEN
        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let login = try #require(logins.first { $0.name == "wellcome-home.com" })
        // createTime: 1740854486, modifyTime: 1740854486
        #expect(login.metadata.creationDate == Date(timeIntervalSince1970: 1740854486))
        #expect(login.metadata.modificationDate == Date(timeIntervalSince1970: 1740854486))
    }

    // MARK: - Error Handling Tests

    @Test
    func invalidZIPThrowsWrongFormat() async {
        // GIVEN
        let invalidData = "not a zip file".data(using: .utf8)!

        // WHEN/THEN
        await #expect(throws: ExternalServiceImportError.wrongFormat) {
            try await interactor.importService(.protonPass, content: .file(invalidData))
        }
    }

    @Test
    func invalidJSONThrowsWrongFormat() async {
        // GIVEN - Create a valid ZIP with invalid JSON
        let invalidJSON = "not valid json".data(using: .utf8)!

        // WHEN/THEN
        await #expect(throws: ExternalServiceImportError.wrongFormat) {
            try await interactor.importService(.protonPass, content: .file(invalidJSON))
        }
    }

    @Test
    func missingVaultThrowsWrongFormat() async throws {
        // GIVEN
        mockMainRepository.withSelectedVault(nil)
        let data = try loadProtonPassTestData()

        // WHEN/THEN
        await #expect(throws: ExternalServiceImportError.wrongFormat) {
            try await interactor.importService(.protonPass, content: .file(data))
        }
    }

    // MARK: - CSV Import Tests

    @Test
    func importProtonPassCSVFile() async throws {
        // GIVEN
        let data = try loadProtonPassCSVTestData()

        // WHEN
        let result = try await interactor.importService(.protonPass, content: .file(data))

        // THEN
        // The ProtonPass.csv contains:
        // - 2 login items
        // - 2 credit cards
        // - 1 secure note
        // - 1 wifi
        // - 12 items converted to secure notes (1 identity + 10 custom + 1 sshKey)
        let logins = result.items.filter { if case .login = $0 { return true } else { return false } }
        let cards = result.items.filter { if case .paymentCard = $0 { return true } else { return false } }
        let notes = result.items.filter { if case .secureNote = $0 { return true } else { return false } }
        let wifis = result.items.filter { if case .wifi = $0 { return true } else { return false } }

        #expect(logins.count == 2)
        #expect(cards.count == 2)
        #expect(notes.count == 13) // 1 native + 12 converted
        #expect(wifis.count == 1)
        #expect(result.tags.isEmpty)
        #expect(result.itemsConvertedToSecureNotes == 12)
    }

    @Test
    func importLoginFromCSV() async throws {
        // GIVEN
        let data = try loadProtonPassCSVTestData()

        // WHEN
        let result = try await interactor.importService(.protonPass, content: .file(data))

        // THEN
        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let login = try #require(logins.first { $0.name == "wellcome-home.com" })
        #expect(login.content.username == "mark")

        let password = try #require(decrypt(login.content.password))
        #expect(password == "Washout2-Professor5-Antibody1-Lustfully9-Barrel5")

        #expect(login.content.uris?.first?.uri == "https://wellcome-home.com")
        #expect(login.metadata.creationDate == Date(timeIntervalSince1970: 1740854486))
    }

    @Test
    func importLoginWithMultipleURLsFromCSV() async throws {
        // GIVEN - CSV with multiple comma-separated URLs
        let csvContent = """
        type,name,url,email,username,password,note,totp,vault,createTime,modifyTime
        login,Test Multiple URLs,"https://example.com, https://example.org, https://example.net",,,testpass,Test note,,,1740854486,1740854486
        """
        let data = csvContent.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.protonPass, content: .file(data))

        // THEN
        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let login = try #require(logins.first { $0.name == "Test Multiple URLs" })

        // Verify all three URLs were parsed
        let uris = try #require(login.content.uris)
        #expect(uris.count == 3)
        #expect(uris[0].uri == "https://example.com")
        #expect(uris[0].match == .domain)
        #expect(uris[1].uri == "https://example.org")
        #expect(uris[1].match == .domain)
        #expect(uris[2].uri == "https://example.net")
        #expect(uris[2].match == .domain)
    }

    @Test
    func importLoginWithSingleURLFromCSV() async throws {
        // GIVEN - CSV with single URL (backward compatibility test)
        let csvContent = """
        type,name,url,email,username,password,note,totp,vault,createTime,modifyTime
        login,Test Single URL,https://single-example.com,,,testpass,Test note,,,1740854486,1740854486
        """
        let data = csvContent.data(using: .utf8)!

        // WHEN
        let result = try await interactor.importService(.protonPass, content: .file(data))

        // THEN
        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let login = try #require(logins.first { $0.name == "Test Single URL" })

        // Verify single URL still works
        let uris = try #require(login.content.uris)
        #expect(uris.count == 1)
        #expect(uris[0].uri == "https://single-example.com")
        #expect(uris[0].match == .domain)
    }

    @Test
    func importCreditCardFromCSV() async throws {
        // GIVEN
        mockPaymentCardUtilityInteractor
            .withCardNumberMask { _ in "1238" }
            .withDetectCardIssuer { _ in nil }

        let data = try loadProtonPassCSVTestData()

        // WHEN
        let result = try await interactor.importService(.protonPass, content: .file(data))

        // THEN
        let cards = result.items.compactMap { item -> PaymentCardItemData? in
            if case .paymentCard(let card) = item { return card }
            return nil
        }

        let card = try #require(cards.first { $0.name == "Karta 1238" })
        #expect(card.content.cardHolder == "Simon H Bron")

        let cardNumber = try #require(decrypt(card.content.cardNumber))
        #expect(cardNumber == "1234123413241238")

        let securityCode = try #require(decrypt(card.content.securityCode))
        #expect(securityCode == "810")

        let expirationDate = try #require(decrypt(card.content.expirationDate))
        #expect(expirationDate == "10/30")

        let notes = try #require(card.content.notes)
        #expect(notes == "Note to card\n\nPin: 111111\n\nVault: Personal")
    }

    @Test
    func importSecureNoteFromCSV() async throws {
        // GIVEN
        let data = try loadProtonPassCSVTestData()

        // WHEN
        let result = try await interactor.importService(.protonPass, content: .file(data))

        // THEN
        let notes = result.items.compactMap { item -> SecureNoteItemData? in
            if case .secureNote(let note) = item { return note }
            return nil
        }

        let note = try #require(notes.first { $0.name == "Sekure Notę" })
        let text = try #require(decrypt(note.content.text))
        #expect(text == "Trudny język Polski język jest być")
        #expect(note.content.additionalInfo == "Vault: Personal")
    }

    @Test
    func importIdentityFromCSV() async throws {
        // GIVEN
        let data = try loadProtonPassCSVTestData()

        // WHEN
        let result = try await interactor.importService(.protonPass, content: .file(data))

        // THEN
        let notes = result.items.compactMap { item -> SecureNoteItemData? in
            if case .secureNote(let note) = item { return note }
            return nil
        }

        let identityNote = try #require(notes.first { $0.name == "Paszport z Israela (Identity)" })
        let text = try #require(decrypt(identityNote.content.text))
        // CSV uses formatContentDictionary (alphabetically sorted, camelCase to Title Case)
        let expectedText = """
            City: Miasto W Izraelu
            Country Or Region: Israel
            Email: jan@goldstein.com
            Full Name: Jan Goldstein
            License Number: NR LICENCJI\(" ")
            Organization: Nso
            Passport Number: NR PASZPORTU
            Phone Number: 5642534141
            Second Phone Number: 451245124812
            Social Security Number: SOCIAL NUMBER TUTAJ
            State Or Province: Stan Wyjatkowy
            Street Address: Ani Okresu Ani Adresu
            Website: storna www! po cholere nie wiem
            X Handle: adrss do twitera
            Zip Or Postal Code: 112112

            Vault: Personal
            """
        #expect(text == expectedText)
    }

    @Test
    func importWiFiFromCSV() async throws {
        // GIVEN
        let data = try loadProtonPassCSVTestData()

        // WHEN
        let result = try await interactor.importService(.protonPass, content: .file(data))

        // THEN
        let wifis = result.items.compactMap { item -> WiFiItemData? in
            if case .wifi(let wifi) = item { return wifi }
            return nil
        }

        let wifi = try #require(wifis.first { $0.name == "Moje WiFi" })
        #expect(wifi.content.ssid == nil) // CSV format doesn't include SSID
        #expect(wifi.content.securityType == .wpa2) // CSV format doesn't include security type
        #expect(wifi.content.hidden == false)

        let password = try #require(decrypt(wifi.content.password))
        #expect(password == "haslo111")

        let notes = try #require(wifi.content.notes)
        #expect(notes == "Ta normalna\n\nVault: Personal")
    }

    // MARK: - Comprehensive CSV Import Test

    @Test
    func importAllValuesFromProtonPassCSVFile() async throws {
        // GIVEN - Use real implementations
        let realPaymentCardUtilityInteractor = PaymentCardUtilityInteractor()
        let realURIInteractor = URIInteractor(mainRepository: mockMainRepository)
        let realInteractor = ExternalServiceImportInteractor(
            mainRepository: mockMainRepository,
            uriInteractor: realURIInteractor,
            paymentCardUtilityInteractor: realPaymentCardUtilityInteractor
        )

        let data = try loadProtonPassCSVTestData()

        // WHEN
        let result = try await realInteractor.importService(.protonPass, content: .file(data))

        // THEN - Verify result summary
        #expect(result.items.count == 18)
        #expect(result.tags.isEmpty)
        #expect(result.itemsConvertedToSecureNotes == 12)

        // Extract items by type
        let logins = result.items.compactMap { if case .login(let l) = $0 { return l } else { return nil } }
        let cards = result.items.compactMap { if case .paymentCard(let c) = $0 { return c } else { return nil } }
        let notes = result.items.compactMap { if case .secureNote(let n) = $0 { return n } else { return nil } }
        let wifis = result.items.compactMap { if case .wifi(let w) = $0 { return w } else { return nil } }

        #expect(logins.count == 2)
        #expect(cards.count == 2)
        #expect(notes.count == 13)
        #expect(wifis.count == 1)

        // MARK: Login 1 - "wellcome-home.com"
        let welcomeLogin = try #require(logins.first { $0.name == "wellcome-home.com" })
        #expect(welcomeLogin.vaultId == testVaultID)
        #expect(welcomeLogin.content.username == "mark")
        let welcomePassword = try #require(decrypt(welcomeLogin.content.password))
        #expect(welcomePassword == "Washout2-Professor5-Antibody1-Lustfully9-Barrel5")
        #expect(welcomeLogin.content.uris?[0].uri == "https://wellcome-home.com")
        #expect(welcomeLogin.content.uris?[0].match == .domain)
        #expect(welcomeLogin.content.notes == "Vault: Personal")
        #expect(welcomeLogin.metadata.protectionLevel == .normal)
        #expect(welcomeLogin.metadata.trashedStatus == .no)
        #expect(welcomeLogin.metadata.tagIds == nil)
        #expect(welcomeLogin.metadata.creationDate == Date(timeIntervalSince1970: 1740854486))
        #expect(welcomeLogin.metadata.modificationDate == Date(timeIntervalSince1970: 1740854486))

        // MARK: Login 2 - "Przykład tytuł Login"
        let przykladLogin = try #require(logins.first { $0.name == "Przykład tytuł Login" })
        #expect(przykladLogin.content.username == "simon@kac.vegas")
        let przykladPassword = try #require(decrypt(przykladLogin.content.password))
        #expect(przykladPassword == "Tarnish9-Green2-Scanner8-Unretired9-Operable7")
        #expect(przykladLogin.content.uris?[0].uri == "https://onet.com")
        #expect(przykladLogin.content.notes == "Notatka do login\n\nVault: Personal")
        #expect(przykladLogin.metadata.creationDate == Date(timeIntervalSince1970: 1766050424))
        #expect(przykladLogin.metadata.modificationDate == Date(timeIntervalSince1970: 1766050424))

        // MARK: Credit Card 1 - "Karta 1238"
        let karta1238 = try #require(cards.first { $0.name == "Karta 1238" })
        #expect(karta1238.vaultId == testVaultID)
        #expect(karta1238.content.cardHolder == "Simon H Bron")
        let karta1238Number = try #require(decrypt(karta1238.content.cardNumber))
        #expect(karta1238Number == "1234123413241238")
        let karta1238CVV = try #require(decrypt(karta1238.content.securityCode))
        #expect(karta1238CVV == "810")
        let karta1238Exp = try #require(decrypt(karta1238.content.expirationDate))
        #expect(karta1238Exp == "10/30")
        let karta1238Notes = try #require(karta1238.content.notes)
        #expect(karta1238Notes == "Note to card\n\nPin: 111111\n\nVault: Personal")
        #expect(karta1238.metadata.creationDate == Date(timeIntervalSince1970: 1764445742))

        // MARK: Credit Card 2 - "Karta 2"
        let karta2 = try #require(cards.first { $0.name == "Karta 2" })
        #expect(karta2.content.cardHolder == "Marek Hodler")
        let karta2Number = try #require(decrypt(karta2.content.cardNumber))
        #expect(karta2Number == "1234514545151848")
        let karta2CVV = try #require(decrypt(karta2.content.securityCode))
        #expect(karta2CVV == "555")
        let karta2Exp = try #require(decrypt(karta2.content.expirationDate))
        #expect(karta2Exp == "12/18")
        let karta2Notes = try #require(karta2.content.notes)
        #expect(karta2Notes == "Ktoś do karty dopisał notatkę\n\nPin: 1234\n\nVault: Personal")

        // MARK: Secure Note - "Sekure Notę"
        let secureNote = try #require(notes.first { $0.name == "Sekure Notę" })
        #expect(secureNote.vaultId == testVaultID)
        let secureNoteText = try #require(decrypt(secureNote.content.text))
        #expect(secureNoteText == "Trudny język Polski język jest być")
        #expect(secureNote.content.additionalInfo == "Vault: Personal")
        #expect(secureNote.metadata.creationDate == Date(timeIntervalSince1970: 1766050464))

        // MARK: Identity -> Secure Note - "Paszport z Israela"
        let identity = try #require(notes.first { $0.name == "Paszport z Israela (Identity)" })
        let identityText = try #require(decrypt(identity.content.text))
        let expectedIdentityText = """
            City: Miasto W Izraelu
            Country Or Region: Israel
            Email: jan@goldstein.com
            Full Name: Jan Goldstein
            License Number: NR LICENCJI\(" ")
            Organization: Nso
            Passport Number: NR PASZPORTU
            Phone Number: 5642534141
            Second Phone Number: 451245124812
            Social Security Number: SOCIAL NUMBER TUTAJ
            State Or Province: Stan Wyjatkowy
            Street Address: Ani Okresu Ani Adresu
            Website: storna www! po cholere nie wiem
            X Handle: adrss do twitera
            Zip Or Postal Code: 112112

            Vault: Personal
            """
        #expect(identityText == expectedIdentityText)

        // MARK: WiFi - "Moje WiFi"
        let wifi = try #require(wifis.first { $0.name == "Moje WiFi" })
        #expect(wifi.content.ssid == nil) // CSV format doesn't include SSID
        #expect(wifi.content.securityType == .wpa2)
        #expect(wifi.content.hidden == false)
        let wifiPassword = try #require(decrypt(wifi.content.password))
        #expect(wifiPassword == "haslo111")
        let wifiNotes = try #require(wifi.content.notes)
        #expect(wifiNotes == "Ta normalna\n\nVault: Personal")

        // MARK: SSH Key -> Secure Note - "Klucz ssh"
        let sshKey = try #require(notes.first { $0.name == "Klucz ssh (SshKey)" })
        let sshKeyText = try #require(decrypt(sshKey.content.text))
        #expect(sshKeyText == "Notę jak zwykle\n\nVault: Personal")

        // MARK: Custom items -> Secure Notes
        let apiNote = try #require(notes.first { $0.name == "API tytuł (Custom)" })
        let apiText = try #require(decrypt(apiNote.content.text))
        #expect(apiText == "Notatka\n\nVault: Personal")

        let dbNote = try #require(notes.first { $0.name == "Baza danych tytuł (Custom)" })
        let dbText = try #require(decrypt(dbNote.content.text))
        #expect(dbText == "Notatka\n\nVault: Personal")

        let serverNote = try #require(notes.first { $0.name == "Tytuł serwer (Custom)" })
        let serverText = try #require(decrypt(serverNote.content.text))
        #expect(serverText == "Notę\n\nVault: Personal")

        let licenseNote = try #require(notes.first { $0.name == "Licencja softu (Custom)" })
        let licenseText = try #require(decrypt(licenseNote.content.text))
        #expect(licenseText == "Notę\n\nVault: Personal")

        let socialNote = try #require(notes.first { $0.name == "Social Security no (Custom)" })
        let socialText = try #require(decrypt(socialNote.content.text))
        #expect(socialText == "Notę\n\nVault: Personal")

        let medicalNote = try #require(notes.first { $0.name == "Medical wpis (Custom)" })
        let medicalText = try #require(decrypt(medicalNote.content.text))
        #expect(medicalText == "Notę\n\nVault: Personal")

        let rewardsNote = try #require(notes.first { $0.name == "Rewars próg (Custom)" })
        let rewardsText = try #require(decrypt(rewardsNote.content.text))
        #expect(rewardsText == "Notka\n\nVault: Personal")
    }

    // MARK: - Helper Methods

    private func loadProtonPassTestData() throws -> Data {
        guard let url = Bundle(for: MockMainRepository.self)
            .url(forResource: "ProtonPass", withExtension: "zip") else {
            throw TestError.resourceNotFound("ProtonPass.zip test resource not found")
        }
        return try Data(contentsOf: url)
    }

    private func loadProtonPassCSVTestData() throws -> Data {
        guard let url = Bundle(for: MockMainRepository.self)
            .url(forResource: "ProtonPass", withExtension: "csv") else {
            throw TestError.resourceNotFound("ProtonPass.csv test resource not found")
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
