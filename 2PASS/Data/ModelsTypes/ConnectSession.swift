// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CryptoKit
import Common

public struct ConnectSession: Identifiable {
    public let version: Int
    public let sessionId: String
    public let pkPersBeHex: String
    public let pkEpheBeHex: String
    public let signatureHex: String
    
    public var id: String {
        sessionId
    }
    
    public var data: Data? {
        "\(sessionId)\(pkPersBeHex)\(pkEpheBeHex)".data(using: .utf8)
    }
    
    public init(version: Int, sessionId: String, pkPersBeHex: String, pkEpheBeHex: String, signatureHex: String) {
        self.version = version
        self.sessionId = sessionId
        self.pkPersBeHex = pkPersBeHex
        self.pkEpheBeHex = pkEpheBeHex
        self.signatureHex = signatureHex
    }
    
    public func verify() -> Bool {
        guard let data else {
            return false
        }
        
        let key = Data(hexString: pkPersBeHex)!
        let signature = Data(hexString: signatureHex)!

        do {
            let publicKey = try P256.Signing.PublicKey(compressedRepresentation: key)
            let signatureECDSA = try P256.Signing.ECDSASignature(rawRepresentation: signature)
            return publicKey.isValidSignature(signatureECDSA, for: data)
        } catch {
            Log("Connect session has wrong signature", module: .connect)
            return false
        }
    }
}

extension ConnectSession {
    
    public init?(qrCode: String) {
        guard let data = Data(base64Encoded: qrCode),
            let dataString = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        let elements = dataString.split(separator: ":").map(String.init)
        
        guard elements.count == 5, let version = Int(elements[0]) else {
            return nil
        }
                
        self = ConnectSession(
            version: version,
            sessionId: elements[1],
            pkPersBeHex: elements[2],
            pkEpheBeHex: elements[3],
            signatureHex: elements[4]
        )
    }
}
