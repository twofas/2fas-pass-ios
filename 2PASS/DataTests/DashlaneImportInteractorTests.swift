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

@Suite("Import Dashlane WiFi file - Unit Tests")
struct DashlaneImportInteractorTests {
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
    func unrecognizedCSVReturnsEmptyResult() async throws {
        let invalidData = "not,valid,csv,without,ssid".data(using: .utf8)!

        let result = try await interactor.importService(.dashlaneMobile, content: .file(invalidData))

        #expect(result.items.isEmpty)
    }

    @Test
    func missingVaultThrowsWrongFormat() async throws {
        mockMainRepository.withSelectedVault(nil)
        let data = try loadDashlaneWiFiTestData()

        await #expect(throws: ExternalServiceImportError.wrongFormat) {
            try await interactor.importService(.dashlaneMobile, content: .file(data))
        }
    }

    @Test
    func emptyCSVWithHeadersReturnsEmptyResult() async throws {
        let csvData = "ssid,passphrase,name,note,hidden,encription_type\n".data(using: .utf8)!

        let result = try await interactor.importService(.dashlaneMobile, content: .file(csvData))

        #expect(result.items.isEmpty)
        #expect(result.tags.isEmpty)
        #expect(result.itemsConvertedToSecureNotes == 0)
    }

    @Test
    func wifiItemsAreNotCountedAsConvertedToSecureNotes() async throws {
        let data = try loadDashlaneWiFiTestData()

        let result = try await interactor.importService(.dashlaneMobile, content: .file(data))

        #expect(result.itemsConvertedToSecureNotes == 0)
        #expect(!result.items.isEmpty)
    }

    @Test
    func wifiImportCreatesNativeWiFiItems() async throws {
        let data = try loadDashlaneWiFiTestData()

        let result = try await interactor.importService(.dashlaneMobile, content: .file(data))

        for item in result.items {
            #expect(item.asWiFi != nil)
        }
    }

    @Test
    func unsecuredEncryptionTypeMapsToNone() async throws {
        let csvData = """
        ssid,passphrase,name,note,hidden,encription_type
        TestNetwork,,Test,,,unsecured
        """.data(using: .utf8)!

        let result = try await interactor.importService(.dashlaneMobile, content: .file(csvData))

        let wifiItem = try #require(result.items.first?.asWiFi)
        #expect(wifiItem.content.securityType == .none)
    }

    @Test
    func wpa2EncryptionTypeMapsCorrectly() async throws {
        let csvData = """
        ssid,passphrase,name,note,hidden,encription_type
        TestNetwork,secret123,Test,,,wpa2
        """.data(using: .utf8)!

        let result = try await interactor.importService(.dashlaneMobile, content: .file(csvData))

        let wifiItem = try #require(result.items.first?.asWiFi)
        #expect(wifiItem.content.securityType == .wpa2)
    }

    @Test
    func unknownEncryptionTypeDefaultsToWPA2() async throws {
        let csvData = """
        ssid,passphrase,name,note,hidden,encription_type
        TestNetwork,secret123,Test,,,somethingNew
        """.data(using: .utf8)!

        let result = try await interactor.importService(.dashlaneMobile, content: .file(csvData))

        let wifiItem = try #require(result.items.first?.asWiFi)
        #expect(wifiItem.content.securityType == .wpa2)
    }

    @Test
    func hiddenTrueParsesCorrectly() async throws {
        let csvData = """
        ssid,passphrase,name,note,hidden,encription_type
        HiddenNet,pass123,Hidden Network,,true,wpa2
        """.data(using: .utf8)!

        let result = try await interactor.importService(.dashlaneMobile, content: .file(csvData))

        let wifiItem = try #require(result.items.first?.asWiFi)
        #expect(wifiItem.content.hidden == true)
    }

    @Test
    func hiddenFalseParsesCorrectly() async throws {
        let csvData = """
        ssid,passphrase,name,note,hidden,encription_type
        VisibleNet,pass123,Visible Network,,false,wpa2
        """.data(using: .utf8)!

        let result = try await interactor.importService(.dashlaneMobile, content: .file(csvData))

        let wifiItem = try #require(result.items.first?.asWiFi)
        #expect(wifiItem.content.hidden == false)
    }

    @Test
    func nameUsesSSIDWhenNameMissing() async throws {
        let csvData = """
        ssid,passphrase,name,note,hidden,encription_type
        MySSID,pass123,,,,wpa2
        """.data(using: .utf8)!

        let result = try await interactor.importService(.dashlaneMobile, content: .file(csvData))

        let wifiItem = try #require(result.items.first?.asWiFi)
        #expect(wifiItem.name == "MySSID")
        #expect(wifiItem.content.ssid == "MySSID")
    }

    @Test
    func noteFieldIsPreserved() async throws {
        let csvData = """
        ssid,passphrase,name,note,hidden,encription_type
        TestNet,pass123,Test,Office WiFi password,false,wpa2
        """.data(using: .utf8)!

        let result = try await interactor.importService(.dashlaneMobile, content: .file(csvData))

        let wifiItem = try #require(result.items.first?.asWiFi)
        #expect(wifiItem.content.notes == "Office WiFi password")
    }

    // MARK: - Helper Methods

    private func loadDashlaneWiFiTestData() throws -> Data {
        guard let url = Bundle(for: MockMainRepository.self).url(forResource: "DashlaneWiFi", withExtension: "csv") else {
            throw TestError.resourceNotFound("DashlaneWiFi.csv test resource not found")
        }
        return try Data(contentsOf: url)
    }

    private func decrypt(_ data: Data?) -> String? {
        DataTests.decrypt(data, using: mockMainRepository)
    }
}

// MARK: - Integration Tests

extension DashlaneImportInteractorTests {

    @Suite("Import Dashlane WiFi test file - comprehensive verification")
    struct IntegrationTests {

        private let mockMainRepository = MockMainRepository.defaultConfiguration()
        private let mockURIInteractor = MockURIInteractor()
        private let mockPaymentCardUtilityInteractor = MockPaymentCardUtilityInteractor()

        @Test
        func importDashlaneWiFiFile() async throws {
            let interactor = ExternalServiceImportInteractor(
                mainRepository: mockMainRepository,
                uriInteractor: mockURIInteractor,
                paymentCardUtilityInteractor: mockPaymentCardUtilityInteractor
            )

            let data = try loadDashlaneWiFiTestData()
            let result = try await interactor.importService(.dashlaneMobile, content: .file(data))

            // Verify result summary
            #expect(result.items.count == 1)
            #expect(result.tags.isEmpty)
            #expect(result.itemsConvertedToSecureNotes == 0)

            // MARK: Item #1 - "internet 2fas" WiFi network
            let wifi1 = try #require(result.items.first?.asWiFi)
            #expect(wifi1.vaultId == mockMainRepository.selectedVault?.vaultID)
            #expect(wifi1.name == "internet 2fas")
            #expect(wifi1.content.name == "internet 2fas")
            #expect(wifi1.content.ssid == "2fas internet")

            let password = try #require(decrypt(wifi1.content.password))
            #expect(password == "12346700018488")

            #expect(wifi1.content.securityType == .none)
            #expect(wifi1.content.hidden == false)
            #expect(wifi1.content.notes == "Eksport Internetu")

            #expect(wifi1.metadata.protectionLevel == .normal)
            #expect(wifi1.metadata.trashedStatus == .no)
            #expect(wifi1.metadata.tagIds == nil)
        }

        // MARK: - Helper Methods

        private func loadDashlaneWiFiTestData() throws -> Data {
            guard let url = Bundle(for: MockMainRepository.self).url(forResource: "DashlaneWiFi", withExtension: "csv") else {
                throw TestError.resourceNotFound("DashlaneWiFi.csv test resource not found")
            }
            return try Data(contentsOf: url)
        }

        private func decrypt(_ data: Data?) -> String? {
            DataTests.decrypt(data, using: mockMainRepository)
        }
    }
}
