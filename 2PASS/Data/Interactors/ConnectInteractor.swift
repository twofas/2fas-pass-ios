// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CryptoKit
import Gzip
import Common

extension Notification.Name {
    public static let connectPullReqestDidChangeNotification = Notification.Name("ConnectPullReqestDidChangeNotification")
}

public enum ConnectError: Error {
    case createKeysFailure(Error?)
    case missingDeviceId
    case keyVerificationFailure
    case encryptionFailure
    case decryptionFailure
    case networkError(Error)
    case saltVerificationFailed
    case cancelled
    case wrongSessionId
    case webSocketClosed
    case missingItem
    case badNotificationData
    case noWebBrowserForNotification
    case missingSessionId
    case badData
    case itemsLimitReached(Int)
}

public typealias ConnectContinuation = (accepted: Bool, passwordID: PasswordID?)

public protocol ConnectInteracting: AnyObject {
    
    @MainActor
    func isKnownBrowser(from session: ConnectSession) -> Bool
    
    func validateNotification(_ notification: AppNotification) async -> Bool
    
    func connect(with session: ConnectSession,
                 progress: @escaping (Float) -> Void,
                 onReceiveBrowserInfo: @escaping (WebBrowser) -> Void) async throws
    
    func connect(for notification: AppNotification,
                 progress: @escaping (Float) -> Void,
                 onReceiveBrowserInfo: @escaping (WebBrowser) -> Void,
                 shouldPerfromAction: @escaping (ConnectAction) async -> ConnectContinuation) async throws
}

final class ConnectInteractor: ConnectInteracting {
    
    let mainRepository: MainRepository
    let webBrowsersInteractor: WebBrowsersInteracting
    let connectExportInteractor: ConnectExportInteracting
    let passwordInteractor: PasswordInteracting
    let uriInteractor: URIInteracting
    let paymentStatusInteractor: PaymentStatusInteracting
    
    init(mainRepository: MainRepository, passwordInteractor: PasswordInteracting, webBrowsersInteractor: WebBrowsersInteracting, connectExportInteractor: ConnectExportInteracting, uriInteractor: URIInteracting, paymentStatusInteractor: PaymentStatusInteracting) {
        self.mainRepository = mainRepository
        self.webBrowsersInteractor = webBrowsersInteractor
        self.connectExportInteractor = connectExportInteractor
        self.passwordInteractor = passwordInteractor
        self.uriInteractor = uriInteractor
        self.paymentStatusInteractor = paymentStatusInteractor
    }
    
    func verifySalt(_ hkdfSaltEnc: String, keys: SessionKeys) throws {
        guard let hkdfSaltEncData = Data(base64Encoded: hkdfSaltEnc) else {
            throw ConnectError.keyVerificationFailure
        }
        
        let decrypted = mainRepository.decrypt(hkdfSaltEncData, key: keys.sessionKey)
        guard decrypted == keys.hkdfSalt else {
            throw ConnectError.keyVerificationFailure
        }
    }
    
    struct SessionKeys {
        let sessionKey: SymmetricKey
        let publicKey: P256.KeyAgreement.PublicKey
        let hkdfSalt: Data
    }
    
    func createKeys(pkEpheBeHex: String) throws(ConnectError) -> SessionKeys {
        do {
            let ephePrivateKey = P256.KeyAgreement.PrivateKey(compactRepresentable: true)
            let ephePublicKey = ephePrivateKey.publicKey
            
            guard let pkEpheBeData = Data(hexString: pkEpheBeHex) else {
                throw ConnectError.badData
            }
            
            let pkEpheBe = try P256.KeyAgreement.PublicKey(compressedRepresentation: pkEpheBeData)
            let shared = try ephePrivateKey.sharedSecretFromKeyAgreement(with: pkEpheBe)
            
            guard let hkdfSalt = mainRepository.generateRandom(byteCount: Config.Connect.hkdfSaltByteCount) else {
                throw ConnectError.createKeysFailure(nil)
            }
            
            let sessionKey = shared.hkdfDerivedSymmetricKey(
                using: SHA256.self,
                salt: hkdfSalt,
                sharedInfo: Keys.Connect.session.data(using: .utf8)!,
                outputByteCount: 32
            )
            
            return SessionKeys(sessionKey: sessionKey, publicKey: ephePublicKey, hkdfSalt: hkdfSalt)
        } catch {
            throw ConnectError.createKeysFailure(error)
        }
    }
}
