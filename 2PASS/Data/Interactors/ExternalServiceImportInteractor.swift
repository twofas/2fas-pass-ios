// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public enum ExternalServiceImportError: Error {
    case wrongFormat
    case wrongFileSize
    case cantReadFile
}

public protocol ExternalServiceImportInteracting: AnyObject {

    func openFile(from url: URL) async throws(ExternalServiceImportError) -> Data

    func importService(
        _ service: ExternalService,
        content: Data
    ) async throws(ExternalServiceImportError) -> [ItemData]
}

final class ExternalServiceImportInteractor {
    private let mainRepository: MainRepository
    private let context: ImportContext

    init(
        mainRepository: MainRepository,
        uriInteractor: URIInteracting,
        paymentCardUtilityInteractor: PaymentCardUtilityInteracting
    ) {
        self.mainRepository = mainRepository
        self.context = ImportContext(
            mainRepository: mainRepository,
            uriInteractor: uriInteractor,
            paymentCardUtilityInteractor: paymentCardUtilityInteractor
        )
    }
}

extension ExternalServiceImportInteractor: ExternalServiceImportInteracting {

    func openFile(from url: URL) async throws(ExternalServiceImportError) -> Data {
        guard let fileURL = mainRepository.copyFileToLocalIfNeeded(from: url) else {
            throw .cantReadFile
        }

        guard let fileSize = mainRepository.checkFileSize(for: fileURL) else {
            throw .wrongFileSize
        }

        guard fileSize < Config.maximumExternalImportFileSize else {
            throw .wrongFileSize
        }

        guard let data = await mainRepository.readFileData(from: fileURL) else {
            throw .cantReadFile
        }

        return data
    }

    func importService(
        _ service: ExternalService,
        content: Data
    ) async throws(ExternalServiceImportError) -> [ItemData] {
        switch service {
        case .onePassword:
            try await OnePasswordImporter(context: context).import(content)
        case .bitWarden:
            try await BitWardenImporter(context: context).import(content)
        case .chrome:
            try await ChromeImporter(context: context).import(content)
        case .dashlaneMobile:
            try await DashlaneImporter(context: context).importMobile(content)
        case .dashlaneDesktop:
            try await DashlaneImporter(context: context).importDesktop(content)
        case .lastPass:
            try await LastPassImporter(context: context).import(content)
        case .protonPass:
            try await ProtonPassImporter(context: context).import(content)
        case .applePasswordsMobile:
            try await ApplePasswordsImporter(context: context).importMobile(content)
        case .applePasswordsDesktop:
            try await ApplePasswordsImporter(context: context).importDesktop(content)
        case .firefox:
            try await FirefoxImporter(context: context).import(content)
        case .keePass:
            try await KeePassImporter(context: context).import(content)
        case .keePassXC:
            try await KeePassXCImporter(context: context).import(content)
        case .microsoftEdge:
            try await MicrosoftEdgeImporter(context: context).import(content)
        case .enpass:
            try await EnpassImporter(context: context).import(content)
        case .keeper:
            try await KeeperImporter(context: context).import(content)
        }
    }
}

// MARK: - ImportContext

extension ExternalServiceImportInteractor {

    struct ImportContext {
        let mainRepository: MainRepository
        let uriInteractor: URIInteracting
        let paymentCardUtilityInteractor: PaymentCardUtilityInteracting

        var selectedVaultId: VaultID? {
            mainRepository.selectedVault?.vaultID
        }

        var currentProtectionLevel: ItemProtectionLevel {
            mainRepository.currentDefaultProtectionLevel
        }

        var jsonDecoder: JSONDecoder {
            mainRepository.jsonDecoder
        }

        func encryptSecureField(_ string: String, for protectionLevel: ItemProtectionLevel) -> Data? {
            guard let key = mainRepository.getKey(isPassword: true, protectionLevel: protectionLevel),
                  let data = string.data(using: .utf8),
                  let encrypted = mainRepository.encrypt(data, key: key) else {
                return nil
            }
            return encrypted
        }

        func formatDictionary(
            _ dict: [String: String],
            excludingKeys: Set<String>,
            keyMap: [String: String] = [:]
        ) -> String? {
            let result = dict
                .filter { !excludingKeys.contains($0.key) && !$0.value.isEmpty }
                .map {
                    (key: keyMap[$0.key] ?? $0.key.replacingOccurrences(of: "_", with: " "), value: $0.value)
                }
                .sorted { $0.key < $1.key }
                .map { "\($0.key.capitalizedFirstLetter): \($0.value)" }
                .joined(separator: "\n")
            return result.isEmpty ? nil : result
        }

        func mergeNote(_ note: String?, additionalInfo: String?) -> String? {
            if let note, let additionalInfo {
                return note + "\n\n" + additionalInfo
            } else {
                return note ?? additionalInfo
            }
        }

        func makeIconType(uri: String?) -> PasswordIconType {
            guard let uri else {
                return .createDefault(domain: nil)
            }
            let domain = uriInteractor.extractDomain(from: uri)
            return .createDefault(domain: domain)
        }

        func cardNumberMask(from cardNumber: String?) -> String? {
            paymentCardUtilityInteractor.cardNumberMask(from: cardNumber)
        }

        func detectCardIssuer(from cardNumber: String?) -> String? {
            paymentCardUtilityInteractor.detectCardIssuer(from: cardNumber)?.rawValue
        }
    }
}
