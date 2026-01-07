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

public enum ImportContent {
    case file(Data)
    case folder([String: Data])
}

public struct ExternalServiceImportResult {
    public let items: [ItemData]
    public let tags: [ItemTagData]
    public let itemsConvertedToSecureNotes: Int

    public init(items: [ItemData], tags: [ItemTagData] = [], itemsConvertedToSecureNotes: Int = 0) {
        self.items = items
        self.tags = tags
        self.itemsConvertedToSecureNotes = itemsConvertedToSecureNotes
    }
}

public protocol ExternalServiceImportInteracting: AnyObject {

    func open(from url: URL) async throws(ExternalServiceImportError) -> ImportContent

    func importService(
        _ service: ExternalService,
        content: ImportContent
    ) async throws(ExternalServiceImportError) -> ExternalServiceImportResult
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

    func open(from url: URL) async throws(ExternalServiceImportError) -> ImportContent {
        let hasSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard let isDirectory = mainRepository.isDirectory(at: url) else {
            throw .cantReadFile
        }

        if isDirectory {
            guard let files = mainRepository.readFilesFromFolder(
                at: url,
                withExtension: "csv",
                maxFileSize: Config.maximumExternalImportFileSize
            ) else {
                throw .cantReadFile
            }
            return .folder(files)
        } else {
            guard let localURL = mainRepository.copyFileToLocalIfNeeded(from: url) else {
                throw .cantReadFile
            }

            guard let fileSize = mainRepository.checkFileSize(for: localURL) else {
                throw .wrongFileSize
            }

            guard fileSize < Config.maximumExternalImportFileSize else {
                throw .wrongFileSize
            }

            guard let data = mainRepository.readLocalFile(at: localURL) else {
                throw .cantReadFile
            }

            return .file(data)
        }
    }

    func importService(
        _ service: ExternalService,
        content: ImportContent
    ) async throws(ExternalServiceImportError) -> ExternalServiceImportResult {
        switch content {
        case .file(let data):
            try await importServiceFromFile(service, content: data)
        case .folder(let files):
            try await importServiceFromFolder(service, files: files)
        }
    }

    private func importServiceFromFile(
        _ service: ExternalService,
        content: Data
    ) async throws(ExternalServiceImportError) -> ExternalServiceImportResult {
        switch service {
        case .onePassword:
            try await OnePasswordImporter(context: context).import(content)
        case .bitWarden:
            try await BitWardenImporter(context: context).import(content)
        case .chrome:
            ExternalServiceImportResult(items: try await ChromeImporter(context: context).import(content))
        case .dashlaneMobile:
            try await DashlaneImporter(context: context).importMobileCSV([content])
        case .dashlaneDesktop:
            try await DashlaneImporter(context: context).importDesktopZIP(content)
        case .lastPass:
            try await LastPassImporter(context: context).import(content)
        case .protonPass:
            try await ProtonPassImporter(context: context).import(content)
        case .applePasswordsMobile:
            ExternalServiceImportResult(items: try await ApplePasswordsImporter(context: context).importMobile(content))
        case .applePasswordsDesktop:
            ExternalServiceImportResult(items: try await ApplePasswordsImporter(context: context).importDesktop(content))
        case .firefox:
            ExternalServiceImportResult(items: try await FirefoxImporter(context: context).import(content))
        case .keePass:
            try await KeePassImporter(context: context).import(content)
        case .keePassXC:
            try await KeePassXCImporter(context: context).import(content)
        case .microsoftEdge:
            ExternalServiceImportResult(items: try await MicrosoftEdgeImporter(context: context).import(content))
        case .enpass:
            try await EnpassImporter(context: context).import(content)
        case .keeper:
            try await KeeperImporter(context: context).import(content)
        }
    }

    private func importServiceFromFolder(
        _ service: ExternalService,
        files: [String: Data]
    ) async throws(ExternalServiceImportError) -> ExternalServiceImportResult {
        switch service {
        case .dashlaneMobile:
            try await DashlaneImporter(context: context).importMobileCSV(Array(files.values))
        default:
            throw .wrongFormat
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
            _ dict: [String: Any],
            excludingKeys: Set<String> = [],
            keyMap: [String: String] = [:]
        ) -> String? {
            let stringDict = dict.compactMapValues { value -> String? in
                if let string = value as? String {
                    return string
                } else if let int = value as? Int {
                    return String(int)
                } else if let double = value as? Double {
                    return String(double)
                } else if let bool = value as? Bool {
                    return String(bool)
                }
                return nil
            }
            return formatDictionary(stringDict, excludingKeys: excludingKeys, keyMap: keyMap)
        }

        func formatDictionary(
            _ dict: [String: String],
            excludingKeys: Set<String> = [],
            keyMap: [String: String] = [:]
        ) -> String? {
            let result = dict
                .filter { !excludingKeys.contains($0.key) && !$0.value.isEmpty }
                .map {
                    let formattedKey = keyMap[$0.key] ?? formatKey($0.key)
                    return (key: formattedKey, value: $0.value)
                }
                .sorted { $0.key < $1.key }
                .map { "\($0.key): \($0.value)" }
                .joined(separator: "\n")
            return result.isEmpty ? nil : result
        }

        private func formatKey(_ key: String) -> String {
            key.replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(
                    of: "([a-z])([A-Z])",
                    with: "$1 $2",
                    options: .regularExpression
                )
                .replacingOccurrences(
                    of: "([a-zA-Z])([0-9])",
                    with: "$1 $2",
                    options: .regularExpression
                )
                .replacingOccurrences(
                    of: "([0-9])([a-zA-Z])",
                    with: "$1 $2",
                    options: .regularExpression
                )
                .capitalizedFirstLetter
        }

        func mergeNote(_ note: String?, with info: String?) -> String? {
            if let note, let info {
                return note + "\n\n" + info
            } else {
                return note ?? info
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

        /// Converts expiration date from MM/YYYY format to MM/YY format
        /// - Parameter dateString: Date string in "MM/YYYY" format (e.g., "09/2029")
        /// - Returns: Date string in "MM/YY" format (e.g., "09/29") or original string if format doesn't match
        func formatExpirationDate(_ dateString: String?) -> String? {
            guard let dateString = dateString?.nonBlankTrimmedOrNil else { return nil }

            let components = dateString.split(separator: "/")
            guard components.count == 2,
                  let month = components.first,
                  let year = components.last,
                  year.count == 4 else {
                return dateString
            }

            let shortYear = year.suffix(2)
            return "\(month)/\(shortYear)"
        }
    }
}
