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

@Suite("Import KeePassXC file")
struct KeePassXCImportInteractorTests {
    private let mockMainRepository: MockMainRepository
    private let mockURIInteractor: MockURIInteractor
    private let mockPaymentCardUtilityInteractor: MockPaymentCardUtilityInteractor
    private let interactor: ExternalServiceImportInteracting
    private let testVaultID = UUID()

    init() {
        mockMainRepository = MockMainRepository()
        mockURIInteractor = MockURIInteractor()
        mockPaymentCardUtilityInteractor = MockPaymentCardUtilityInteractor()

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

    @Test
    func importFile() async throws {
        let data = try loadTestData()

        let result = try await interactor.importService(.keePassXC, content: .file(data))

        #expect(result.items.count == 4)
        #expect(result.tags.count == 1)
        #expect(result.itemsConvertedToSecureNotes == 0)
    }

    @Test
    func importLoginWithUnknownHeaders() async throws {
        let csvData = """
            "Group","Title","Username","Password","URL","Notes","TOTP","Icon","Last Modified","Created","Custom Field"
            "Root/Personal","Sample Entry","user","pass","https://example.com","Original note","otpauth://totp/Example","1","2025-12-22T19:33:17Z","2025-12-22T19:32:17Z","Custom value"
            """.data(using: .utf8)!

        let result = try await interactor.importService(.keePassXC, content: .file(csvData))

        #expect(result.items.count == 1)
        #expect(result.tags.count == 1)

        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let testLogin = try #require(logins.first)
        #expect(testLogin.name == "Sample Entry")
        #expect(testLogin.content.username == "user")

        let password = try #require(decrypt(testLogin.content.password))
        #expect(password == "pass")

        let expectedNotes = """
        Original note

        Custom Field: Custom value
        TOTP: otpauth://totp/Example
        """
        #expect(testLogin.content.notes == expectedNotes)
    }

    @Test
    func importGroupsAsTags() async throws {
        let csvData = """
            "Group","Title","Username","Password","URL","Notes","Last Modified","Created"
            "Root/Personal","Personal Login","person","pass","https://example.com","Note","2025-12-22T19:33:17Z","2025-12-22T19:32:17Z"
            "Work","Work Login","work","pass","https://work.com","Note","2025-12-22T19:33:17Z","2025-12-22T19:32:17Z"
            """.data(using: .utf8)!

        let result = try await interactor.importService(.keePassXC, content: .file(csvData))

        #expect(result.items.count == 2)
        #expect(result.tags.count == 2)

        let tagIdByName = Dictionary(uniqueKeysWithValues: result.tags.map { ($0.name, $0.tagID) })
        let personalTagId = try #require(tagIdByName["Personal"])
        let workTagId = try #require(tagIdByName["Work"])

        let logins = result.items.compactMap { item -> LoginItemData? in
            if case .login(let login) = item { return login }
            return nil
        }

        let personalLogin = try #require(logins.first { $0.name == "Personal Login" })
        #expect(personalLogin.metadata.tagIds == [personalTagId])

        let workLogin = try #require(logins.first { $0.name == "Work Login" })
        #expect(workLogin.metadata.tagIds == [workTagId])
    }

    private func loadTestData() throws -> Data {
        guard let url = Bundle(for: MockMainRepository.self).url(forResource: "KeePassXC", withExtension: "csv") else {
            throw TestError.resourceNotFound("KeePassXC.csv test resource not found")
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

extension KeePassXCImportInteractorTests {

    @Suite("Import KeePassXC file - comprehensive verification")
    struct IntegrationTests {

        private let mockMainRepository = MockMainRepository.defaultConfiguration()
        private let paymentCardUtilityInteractor = PaymentCardUtilityInteractor()
        private let uriInteractor: URIInteractor

        init() {
            self.uriInteractor = URIInteractor(mainRepository: mockMainRepository)
        }

        @Test
        func importCSVFile() async throws {
            let interactor = ExternalServiceImportInteractor(
                mainRepository: mockMainRepository,
                uriInteractor: uriInteractor,
                paymentCardUtilityInteractor: paymentCardUtilityInteractor
            )

            let data = try loadTestData()
            let result = try await interactor.importService(.keePassXC, content: .file(data))

            #expect(result.items.count == 4)
            #expect(result.tags.count == 1)
            #expect(result.itemsConvertedToSecureNotes == 0)

            let logins = result.items.compactMap { if case .login(let login) = $0 { return login } else { return nil } }
            #expect(logins.count == 4)

            let tagIdByName = Dictionary(uniqueKeysWithValues: result.tags.map { ($0.name, $0.tagID) })
            let podgrupaTagId = try #require(tagIdByName["podgrupa"])

            let dateFormatter = ISO8601DateFormatter()

            // MARK: Login #1 - "Pierwszy element"
            let firstItem = try #require(logins.first { $0.name == "Pierwszy element" })
            #expect(firstItem.vaultId == mockMainRepository.selectedVault?.vaultID)
            #expect(firstItem.content.username == "Arthur")

            let firstPassword = try #require(decrypt(firstItem.content.password))
            #expect(firstPassword == "l<~A_AH_KSgJ<NERw($P")

            #expect(firstItem.content.uris?.count == 1)
            #expect(firstItem.content.uris?[0].uri == "https://www.youtube.com/watch?v=H48B0qhEVGw")
            #expect(firstItem.content.uris?[0].match == .domain)
            #expect(firstItem.content.notes == "Notka do pierwszego elementu")
            #expect(firstItem.metadata.protectionLevel == .normal)
            #expect(firstItem.metadata.trashedStatus == .no)
            #expect(firstItem.metadata.tagIds == nil)
            #expect(firstItem.metadata.creationDate == dateFormatter.date(from: "2025-12-22T19:32:17Z"))
            #expect(firstItem.metadata.modificationDate == dateFormatter.date(from: "2025-12-22T19:33:17Z"))

            // MARK: Login #2 - "Drugi element"
            let secondItem = try #require(logins.first { $0.name == "Drugi element" })
            #expect(secondItem.vaultId == mockMainRepository.selectedVault?.vaultID)
            #expect(secondItem.content.username == "Morgan")

            let secondPassword = try #require(decrypt(secondItem.content.password))
            #expect(secondPassword == "~M\"e5iS**h*U\\[\"7aT%\\")

            #expect(secondItem.content.uris?.count == 1)
            #expect(secondItem.content.uris?[0].uri == "https://2fas.com/")
            #expect(secondItem.content.uris?[0].match == .domain)
            #expect(secondItem.content.notes == "Notka do drugiego elementu")
            #expect(secondItem.metadata.protectionLevel == .normal)
            #expect(secondItem.metadata.trashedStatus == .no)
            #expect(secondItem.metadata.tagIds == nil)
            #expect(secondItem.metadata.creationDate == dateFormatter.date(from: "2025-12-22T19:33:19Z"))
            #expect(secondItem.metadata.modificationDate == dateFormatter.date(from: "2025-12-22T19:33:57Z"))

            // MARK: Login #3 - "Element z custom fieldami"
            let thirdItem = try #require(logins.first { $0.name == "Element z custom fieldami" })
            #expect(thirdItem.vaultId == mockMainRepository.selectedVault?.vaultID)
            #expect(thirdItem.content.username == "Erunestian")

            let thirdPassword = try #require(decrypt(thirdItem.content.password))
            #expect(thirdPassword == "0:Eg4V7N][/:GOFDF44_")

            #expect(thirdItem.content.uris?.count == 1)
            #expect(thirdItem.content.uris?[0].uri == "https://2fas.com/pass/")
            #expect(thirdItem.content.uris?[0].match == .domain)
            #expect(thirdItem.content.notes == "Notka do 3 elementu")
            #expect(thirdItem.metadata.protectionLevel == .normal)
            #expect(thirdItem.metadata.trashedStatus == .no)
            #expect(thirdItem.metadata.tagIds == nil)
            #expect(thirdItem.metadata.creationDate == dateFormatter.date(from: "2025-12-22T19:33:59Z"))
            #expect(thirdItem.metadata.modificationDate == dateFormatter.date(from: "2025-12-22T19:35:15Z"))

            // MARK: Login #4 - "Login do podgrupy"
            let fourthItem = try #require(logins.first { $0.name == "Login do podgrupy" })
            #expect(fourthItem.vaultId == mockMainRepository.selectedVault?.vaultID)
            #expect(fourthItem.content.username == "2")

            let fourthPassword = try #require(decrypt(fourthItem.content.password))
            #expect(fourthPassword == "us~a@8RdFZPgHtG(F)%a")

            #expect(fourthItem.content.uris?.count == 1)
            #expect(fourthItem.content.uris?[0].uri == "https://www.youtube.com/watch?v=nHi-LjQ4528&t=5459s")
            #expect(fourthItem.content.uris?[0].match == .domain)
            #expect(fourthItem.content.notes == "Notka do podgrupy")
            #expect(fourthItem.metadata.protectionLevel == .normal)
            #expect(fourthItem.metadata.trashedStatus == .no)
            #expect(fourthItem.metadata.tagIds == [podgrupaTagId])
            #expect(fourthItem.metadata.creationDate == dateFormatter.date(from: "2026-01-07T14:11:04Z"))
            #expect(fourthItem.metadata.modificationDate == dateFormatter.date(from: "2026-01-07T14:11:36Z"))
        }

        private func loadTestData() throws -> Data {
            guard let url = Bundle(for: MockMainRepository.self).url(forResource: "KeePassXC", withExtension: "csv") else {
                throw TestError.resourceNotFound("KeePassXC.csv test resource not found")
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
}
