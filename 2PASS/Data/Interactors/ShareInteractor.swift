// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import CommonCrypto
import CryptoKit

// MARK: - Result Types

public enum ShareEncryptionMethod {
    case key(Data)
    case password(salt: Data)

    var scheme: ShareSchemeVersion {
        switch self {
        case .key: .v1k
        case .password: .v1p
        }
    }
}

public enum ShareSchemeVersion: String {
    case v1k
    case v1p
}

public struct ShareExportResult {
    public let encryptedData: Data
    public let nonce: Data
    public let encryption: ShareEncryptionMethod

    public init(encryptedData: Data, nonce: Data, encryption: ShareEncryptionMethod) {
        self.encryptedData = encryptedData
        self.nonce = nonce
        self.encryption = encryption
    }
}

public struct ShareLinkComponents {
    public let id: String
    public let nonce: Data
    public let encryption: ShareEncryptionMethod

    public init(id: String, nonce: Data, encryption: ShareEncryptionMethod) {
        self.id = id
        self.nonce = nonce
        self.encryption = encryption
    }
}

// MARK: - Protocol

public protocol ShareInteracting: AnyObject {
    func exportItem(id: ItemID) async throws -> ShareExportResult
    func exportItem(id: ItemID, password: String) async throws -> ShareExportResult
    func fetchSharedSecret(id: String) async throws -> String
    func decryptSharedSecret(encryptedData: String, components: ShareLinkComponents, password: String?) throws -> any ItemDataChangeRequest
    func makeShareURL(id: String, exportResult: ShareExportResult) -> URL?
    func parseShareURL(_ url: URL) -> ShareLinkComponents?
    func parseShareDeepLink(_ url: URL) -> ShareLinkComponents?
}

// MARK: - Implementation

final class ShareInteractor: ShareInteracting {
    private static let pbkdf2Iterations: UInt32 = 600_000

    private let mainRepository: MainRepository
    private let itemsInteractor: ItemsInteracting

    init(mainRepository: MainRepository, itemsInteractor: ItemsInteracting) {
        self.mainRepository = mainRepository
        self.itemsInteractor = itemsInteractor
    }

    // MARK: - Export with random key (v1k)

    func exportItem(id: ItemID) async throws -> ShareExportResult {
        let plaintext = try await preparePlaintext(for: id)

        guard let keyData = mainRepository.generateRandom(byteCount: 32),
              let nonce = mainRepository.generateRandom(byteCount: 12)
        else {
            throw ShareInteractorError.encryptionFailed
        }

        let shareKey = mainRepository.createSymmetricKey(from: keyData)

        guard let encrypted = mainRepository.encryptWithoutNonce(plaintext, key: shareKey, nonce: nonce) else {
            throw ShareInteractorError.encryptionFailed
        }

        return ShareExportResult(
            encryptedData: encrypted,
            nonce: nonce,
            encryption: .key(keyData)
        )
    }

    // MARK: - Export with password (v1p)

    func exportItem(id: ItemID, password: String) async throws -> ShareExportResult {
        let plaintext = try await preparePlaintext(for: id)

        guard let salt = mainRepository.generateRandom(byteCount: 16),
              let nonce = mainRepository.generateRandom(byteCount: 12)
        else {
            throw ShareInteractorError.encryptionFailed
        }

        let keyData = try deriveKey(from: password, salt: salt)
        let shareKey = mainRepository.createSymmetricKey(from: keyData)

        guard let encrypted = mainRepository.encryptWithoutNonce(plaintext, key: shareKey, nonce: nonce) else {
            throw ShareInteractorError.encryptionFailed
        }

        return ShareExportResult(
            encryptedData: encrypted,
            nonce: nonce,
            encryption: .password(salt: salt)
        )
    }

    // MARK: - Import

    func fetchSharedSecret(id: String) async throws -> String {
        let secret = try await mainRepository.fetchSharedSecret(id: id)
        return secret.data
    }

    func decryptSharedSecret(encryptedData: String, components: ShareLinkComponents, password: String?) throws -> any ItemDataChangeRequest {
        guard let ciphertextAndTag = Data(base64Encoded: encryptedData) else {
            throw ShareInteractorError.decodingFailed
        }

        let key: SymmetricKey
        switch components.encryption {
        case .key(let keyData):
            key = mainRepository.createSymmetricKey(from: keyData)

        case .password(let salt):
            guard let password else {
                throw ShareInteractorError.passwordRequired
            }
            let keyData = try deriveKey(from: password, salt: salt)
            key = mainRepository.createSymmetricKey(from: keyData)
        }

        guard let plaintext = mainRepository.decrypt(ciphertextAndTag, key: key, nonce: components.nonce) else {
            throw ShareInteractorError.decryptionFailed
        }

        return try decodeShareContent(from: plaintext)
    }

    // MARK: - URL

    func makeShareURL(id: String, exportResult: ShareExportResult) -> URL? {
        let lastSegment: String
        switch exportResult.encryption {
        case .key(let shareKey):
            lastSegment = shareKey.base64URLEncodedString()
        case .password(let salt):
            lastSegment = salt.base64URLEncodedString()
        }

        let scheme = exportResult.encryption.scheme.rawValue
        let nonceBase64URL = exportResult.nonce.base64URLEncodedString()
        return URL(string: "\(Config.twoFASShareBaseURL)#/\(id)/\(scheme)/\(nonceBase64URL)/\(lastSegment)")
    }

    func parseShareURL(_ url: URL) -> ShareLinkComponents? {
        guard let fragment = url.fragment(percentEncoded: false) else { return nil }

        let parts = fragment
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        return parseShareComponents(from: parts)
    }

    func parseShareDeepLink(_ url: URL) -> ShareLinkComponents? {
        // twofaspass://share/{id}/{scheme}/{nonce}/{key|salt}
        guard url.scheme == "twofaspass", url.host() == "share" else { return nil }

        let parts = url.pathComponents
            .filter { $0 != "/" }

        return parseShareComponents(from: parts)
    }

    private func parseShareComponents(from parts: [String]) -> ShareLinkComponents? {
        // Expected: [<id>, <scheme>, <nonce>, <key|salt>]
        guard parts.count == 4 else { return nil }

        guard let scheme = ShareSchemeVersion(rawValue: parts[1]),
              let nonce = Data(base64URLEncoded: parts[2]),
              let lastData = Data(base64URLEncoded: parts[3])
        else { return nil }

        let encryption: ShareEncryptionMethod
        switch scheme {
        case .v1k:
            encryption = .key(lastData)
        case .v1p:
            encryption = .password(salt: lastData)
        }

        return ShareLinkComponents(
            id: parts[0],
            nonce: nonce,
            encryption: encryption
        )
    }
}

// MARK: - Private

private extension ShareInteractor {

    func preparePlaintext(for id: ItemID) async throws -> Data {
        let item = await MainActor.run {
            itemsInteractor.getItem(for: id, checkInTrash: false)
        }

        guard let item else {
            throw ShareInteractorError.itemNotFound
        }

        let protectionLevel = item.metadata.protectionLevel

        switch item {
        case .login(let login):
            return try mainRepository.jsonEncoder.encode(shareContent(from: login, protectionLevel: protectionLevel))

        case .secureNote(let note):
            return try mainRepository.jsonEncoder.encode(shareContent(from: note, protectionLevel: protectionLevel))

        case .paymentCard(let card):
            return try mainRepository.jsonEncoder.encode(shareContent(from: card, protectionLevel: protectionLevel))

        case .wifi(let wifi):
            return try mainRepository.jsonEncoder.encode(shareContent(from: wifi, protectionLevel: protectionLevel))

        case .raw:
            throw ShareInteractorError.decodingFailed
        }
    }

    // MARK: - Export: item → share content

    func shareContent(from login: LoginItemData, protectionLevel: ItemProtectionLevel) -> ShareSecretContent<ShareLoginContent> {
        ShareSecretContent(
            contentType: ItemContentType.login.rawValue,
            content: ShareLoginContent(
                name: login.content.name,
                username: login.content.username,
                password: decryptSecure(login.content.password, protectionLevel: protectionLevel),
                notes: login.content.notes,
                uris: login.content.uris
            )
        )
    }

    func shareContent(from note: SecureNoteItemData, protectionLevel: ItemProtectionLevel) -> ShareSecretContent<ShareSecureNoteContent> {
        ShareSecretContent(
            contentType: ItemContentType.secureNote.rawValue,
            content: ShareSecureNoteContent(
                name: note.content.name,
                text: decryptSecure(note.content.text, protectionLevel: protectionLevel)
            )
        )
    }

    func shareContent(from card: PaymentCardItemData, protectionLevel: ItemProtectionLevel) -> ShareSecretContent<SharePaymentCardContent> {
        ShareSecretContent(
            contentType: ItemContentType.paymentCard.rawValue,
            content: SharePaymentCardContent(
                name: card.content.name,
                cardHolder: card.content.cardHolder,
                cardNumber: decryptSecure(card.content.cardNumber, protectionLevel: protectionLevel),
                expirationDate: decryptSecure(card.content.expirationDate, protectionLevel: protectionLevel),
                securityCode: decryptSecure(card.content.securityCode, protectionLevel: protectionLevel),
                notes: card.content.notes
            )
        )
    }

    func shareContent(from wifi: WiFiItemData, protectionLevel: ItemProtectionLevel) -> ShareSecretContent<ShareWiFiContent> {
        ShareSecretContent(
            contentType: ItemContentType.wifi.rawValue,
            content: ShareWiFiContent(
                name: wifi.content.name,
                ssid: wifi.content.ssid,
                password: decryptSecure(wifi.content.password, protectionLevel: protectionLevel),
                notes: wifi.content.notes,
                securityType: wifi.content.securityType,
                hidden: wifi.content.hidden
            )
        )
    }

    // MARK: - Helpers

    func decryptSecure(_ data: Data?, protectionLevel: ItemProtectionLevel) -> String? {
        guard let data else { return nil }
        return itemsInteractor.decrypt(data, isSecureField: true, protectionLevel: protectionLevel)
    }

    // MARK: - Import decoding

    func decodeShareContent(from plaintext: Data) throws -> any ItemDataChangeRequest {
        let header = try mainRepository.jsonDecoder.decode(
            ShareSecretHeader.self,
            from: plaintext
        )
        let contentType = ItemContentType(rawValue: header.contentType)

        switch contentType {
        case .login:
            let decoded = try mainRepository.jsonDecoder.decode(
                ShareSecretContent<ShareLoginContent>.self, from: plaintext
            )
            return changeRequest(from: decoded.content)

        case .secureNote:
            let decoded = try mainRepository.jsonDecoder.decode(
                ShareSecretContent<ShareSecureNoteContent>.self, from: plaintext
            )
            return changeRequest(from: decoded.content)

        case .paymentCard:
            let decoded = try mainRepository.jsonDecoder.decode(
                ShareSecretContent<SharePaymentCardContent>.self, from: plaintext
            )
            return changeRequest(from: decoded.content)

        case .wifi:
            let decoded = try mainRepository.jsonDecoder.decode(
                ShareSecretContent<ShareWiFiContent>.self, from: plaintext
            )
            return changeRequest(from: decoded.content)

        case .unknown("custom"):
            let decoded = try mainRepository.jsonDecoder.decode(
                ShareSecretContent<ShareCustomContent>.self, from: plaintext
            )
            return changeRequest(from: decoded.content)

        case .unknown:
            throw ShareInteractorError.unsupportedContentType
        }
    }

    // MARK: - Change request builders

    func changeRequest(from content: ShareLoginContent) -> LoginDataChangeRequest {
        LoginDataChangeRequest(
            name: content.name,
            username: content.username.map { .value($0) },
            password: content.password.map { .value($0) },
            notes: content.notes,
            uris: content.uris
        )
    }

    func changeRequest(from content: ShareSecureNoteContent) -> SecureNoteDataChangeRequest {
        SecureNoteDataChangeRequest(
            name: content.name,
            text: content.text
        )
    }

    func changeRequest(from content: ShareCustomContent) -> SecureNoteDataChangeRequest {
        SecureNoteDataChangeRequest(
            name: nil,
            text: content.text
        )
    }

    func changeRequest(from content: SharePaymentCardContent) -> PaymentCardDataChangeRequest {
        PaymentCardDataChangeRequest(
            name: content.name,
            cardHolder: content.cardHolder,
            cardNumber: content.cardNumber,
            expirationDate: content.expirationDate,
            securityCode: content.securityCode,
            notes: content.notes
        )
    }

    func changeRequest(from content: ShareWiFiContent) -> WiFiDataChangeRequest {
        WiFiDataChangeRequest(
            name: content.name,
            ssid: content.ssid,
            password: content.password,
            notes: content.notes,
            securityType: content.securityType,
            hidden: content.hidden
        )
    }

    func deriveKey(from password: String, salt: Data) throws -> Data {
        guard let passwordData = password.data(using: .utf8) else {
            throw ShareInteractorError.encryptionFailed
        }

        var derivedKey = Data(count: 32)
        let status = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        Self.pbkdf2Iterations,
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        32
                    )
                }
            }
        }

        guard status == kCCSuccess else {
            throw ShareInteractorError.encryptionFailed
        }

        return derivedKey
    }
}

enum ShareInteractorError: Error {
    case itemNotFound
    case decryptionFailed
    case decodingFailed
    case encryptionFailed
    case passwordRequired
    case unsupportedContentType
}
