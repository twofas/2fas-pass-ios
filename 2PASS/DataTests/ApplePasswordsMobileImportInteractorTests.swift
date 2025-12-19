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

@Suite("Import Apple Passwords Mobile file")
struct ApplePasswordsMobileImportInteractorTests {
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
    func importApplePasswordsMobileFile() async throws {
        // GIVEN
        let data = try loadApplePasswordsMobileTestData()

        // WHEN
        let result = try await interactor.importService(.applePasswordsMobile, content: .file(data))

        // THEN
        // The AppleSafariMobile.zip contains passwords CSV and PaymentCards.json
        let logins = result.items.filter { if case .login = $0 { return true } else { return false } }
        let cards = result.items.filter { if case .paymentCard = $0 { return true } else { return false } }

        #expect(logins.count == 3)
        #expect(cards.count == 3)
        #expect(result.tags.isEmpty)
        #expect(result.itemsConvertedToSecureNotes == 0)
    }

    // MARK: - Payment Card Import Tests

    @Test
    func importPaymentCardWithAllFields() async throws {
        // GIVEN
        let data = try loadApplePasswordsMobileTestData()

        // WHEN
        let result = try await interactor.importService(.applePasswordsMobile, content: .file(data))

        // THEN
        let cards = result.items.compactMap { item -> PaymentCardItemData? in
            if case .paymentCard(let card) = item { return card }
            return nil
        }

        // VISA - virtual with all fields
        let visaCard = try #require(cards.first { $0.name == "VISA - virtual" })
        #expect(visaCard.content.cardHolder == "Maciej Szewczyk")

        let cardNumber = try #require(decrypt(visaCard.content.cardNumber))
        #expect(cardNumber == "4779251087305470")

        let expirationDate = try #require(decrypt(visaCard.content.expirationDate))
        #expect(expirationDate == "11/25")

        #expect(visaCard.vaultId == testVaultID)
        #expect(visaCard.metadata.protectionLevel == .normal)
        #expect(visaCard.metadata.trashedStatus == .no)
    }

    @Test
    func importPaymentCardWithMinimalFields() async throws {
        // GIVEN
        let data = try loadApplePasswordsMobileTestData()

        // WHEN
        let result = try await interactor.importService(.applePasswordsMobile, content: .file(data))

        // THEN
        let cards = result.items.compactMap { item -> PaymentCardItemData? in
            if case .paymentCard(let card) = item { return card }
            return nil
        }

        // Visa without cardholder name and expiration
        let visaCard = try #require(cards.first { $0.name == "Visa" })
        #expect(visaCard.content.cardHolder == nil)

        let cardNumber = try #require(decrypt(visaCard.content.cardNumber))
        #expect(cardNumber == "4246710137228318")

        #expect(visaCard.content.expirationDate == nil)
    }

    @Test
    func importPaymentCardWithExpiredDate() async throws {
        // GIVEN
        let data = try loadApplePasswordsMobileTestData()

        // WHEN
        let result = try await interactor.importService(.applePasswordsMobile, content: .file(data))

        // THEN
        let cards = result.items.compactMap { item -> PaymentCardItemData? in
            if case .paymentCard(let card) = item { return card }
            return nil
        }

        // MasterCard with 2022 expiration
        let masterCard = try #require(cards.first { $0.name == "MasterCard" })

        let cardNumber = try #require(decrypt(masterCard.content.cardNumber))
        #expect(cardNumber == "5472670107591883")

        let expirationDate = try #require(decrypt(masterCard.content.expirationDate))
        #expect(expirationDate == "1/22")
    }

    @Test
    func importPaymentCardWithUnknownFieldsInNotes() async throws {
        // GIVEN
        let data = try loadApplePasswordsMobileTestData()

        // WHEN
        let result = try await interactor.importService(.applePasswordsMobile, content: .file(data))

        // THEN
        let cards = result.items.compactMap { item -> PaymentCardItemData? in
            if case .paymentCard(let card) = item { return card }
            return nil
        }

        let visaCard = try #require(cards.first { $0.name == "VISA - virtual" })
        #expect(visaCard.content.notes == nil)
    }

    // MARK: - Login Import Tests

    @Test
    func importLoginItemFromApplePasswordsMobileFile() async throws {
        // GIVEN
        let data = try loadApplePasswordsMobileTestData()

        // WHEN
        let result = try await interactor.importService(.applePasswordsMobile, content: .file(data))

        // THEN
        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        // Verify we have logins
        #expect(logins.count == 3)

        // Find a specific login
        let acrcloudLogin = try #require(logins.first { $0.name == "console.acrcloud.com" })
        #expect(acrcloudLogin.content.username == "user@gmail.com")

        let password = try #require(decrypt(acrcloudLogin.content.password))
        #expect(password == "koqma4-kyCxov-vycpur")

        #expect(acrcloudLogin.content.uris?.first?.uri == "https://console.acrcloud.com/")
    }

    // MARK: - Comprehensive Import Test

    @Test
    func importAllValuesFromApplePasswordsMobileFile() async throws {
        // GIVEN - Use real implementations
        let realURIInteractor = URIInteractor(mainRepository: mockMainRepository)
        let realInteractor = ExternalServiceImportInteractor(
            mainRepository: mockMainRepository,
            uriInteractor: realURIInteractor,
            paymentCardUtilityInteractor: mockPaymentCardUtilityInteractor
        )

        let data = try loadApplePasswordsMobileTestData()

        // WHEN
        let result = try await realInteractor.importService(.applePasswordsMobile, content: .file(data))

        // THEN - Verify result summary
        #expect(result.items.count == 6)  // 3 logins + 3 payment cards
        #expect(result.tags.isEmpty)
        #expect(result.itemsConvertedToSecureNotes == 0)

        // Extract logins and cards
        let logins = result.items.compactMap { if case .login(let l) = $0 { return l } else { return nil } }
        let cards = result.items.compactMap { if case .paymentCard(let c) = $0 { return c } else { return nil } }

        #expect(logins.count == 3)
        #expect(cards.count == 3)

        // MARK: Login - "console.acrcloud.com"
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
        let adobeNa1Login = try #require(logins.first { $0.name == "adobeid-na1.services.adobe.com" })
        #expect(adobeNa1Login.content.username == "user2@cohesiva.com")

        let adobeNa1Password = try #require(decrypt(adobeNa1Login.content.password))
        #expect(adobeNa1Password == "uMF-mL3-yVH-eYM")

        #expect(adobeNa1Login.content.notes == nil)

        // MARK: Login - "adobeid.services.adobe.com (maciej.szewczyk@cohesiva.com)"
        // This login has empty URL and Username
        let adobeLogin = try #require(logins.first { $0.name == "adobeid.services.adobe.com (maciej.szewczyk@cohesiva.com)" })
        #expect(adobeLogin.content.username == nil)
        #expect(adobeLogin.content.uris == nil)

        let adobePassword = try #require(decrypt(adobeLogin.content.password))
        #expect(adobePassword == "austyf-6jekzo-wivhIx")

        // MARK: Payment Card - "VISA - virtual"
        let visaVirtualCard = try #require(cards.first { $0.name == "VISA - virtual" })
        #expect(visaVirtualCard.vaultId == testVaultID)
        #expect(visaVirtualCard.content.cardHolder == "Maciej Szewczyk")

        let visaVirtualCardNumber = try #require(decrypt(visaVirtualCard.content.cardNumber))
        #expect(visaVirtualCardNumber == "4779251087305470")

        let visaVirtualExpiration = try #require(decrypt(visaVirtualCard.content.expirationDate))
        #expect(visaVirtualExpiration == "11/25")

        #expect(visaVirtualCard.content.securityCode == nil)
        #expect(visaVirtualCard.metadata.protectionLevel == .normal)
        #expect(visaVirtualCard.metadata.trashedStatus == .no)
        #expect(visaVirtualCard.metadata.tagIds == nil)
        #expect(visaVirtualCard.content.notes == nil)

        // MARK: Payment Card - "Visa" (minimal fields)
        let visaCard = try #require(cards.first { $0.name == "Visa" })
        #expect(visaCard.content.cardHolder == nil)
        #expect(visaCard.content.expirationDate == nil)

        let visaCardNumber = try #require(decrypt(visaCard.content.cardNumber))
        #expect(visaCardNumber == "4246710137228318")

        // MARK: Payment Card - "MasterCard"
        let masterCard = try #require(cards.first { $0.name == "MasterCard" })

        let masterCardNumber = try #require(decrypt(masterCard.content.cardNumber))
        #expect(masterCardNumber == "5472670107591883")

        let masterCardExpiration = try #require(decrypt(masterCard.content.expirationDate))
        #expect(masterCardExpiration == "1/22")
    }

    // MARK: - Error Handling Tests

    @Test
    func invalidZIPThrowsWrongFormat() async {
        // GIVEN
        let invalidData = "not a zip file".data(using: .utf8)!

        // WHEN/THEN
        await #expect(throws: ExternalServiceImportError.wrongFormat) {
            try await interactor.importService(.applePasswordsMobile, content: .file(invalidData))
        }
    }

    @Test
    func missingVaultThrowsWrongFormat() async throws {
        // GIVEN
        mockMainRepository.withSelectedVault(nil)
        let data = try loadApplePasswordsMobileTestData()

        // WHEN/THEN
        await #expect(throws: ExternalServiceImportError.wrongFormat) {
            try await interactor.importService(.applePasswordsMobile, content: .file(data))
        }
    }

    // MARK: - Helper Methods

    private func loadApplePasswordsMobileTestData() throws -> Data {
        guard let url = Bundle(for: MockMainRepository.self)
            .url(forResource: "AppleSafariMobile", withExtension: "zip") else {
            throw TestError.resourceNotFound("AppleSafariMobile.zip test resource not found")
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
