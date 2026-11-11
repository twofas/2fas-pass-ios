// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Testing
import CryptoKit
import Common
@testable import Data

/// A Connect-shaped code with non-hex fields must be refused, never crash the app.
@Suite("Connect session")
struct ConnectSessionTests {

    @Test func validCodeParsesAndVerifies() {
        let session = ConnectSession(qrCode: ConnectSessionFixture.qrCode())
        #expect(session?.verify() == true)
    }

    @Test func tamperedSignatureDoesNotVerify() {
        #expect(ConnectSession(qrCode: ConnectSessionFixture.qrCode(valid: false))?.verify() == false)
    }

    @Test func verifyWithNonHexFieldsIsFalse() {
        let code = Data("1:abc:zz:zz:zz".utf8).base64EncodedString()
        #expect(ConnectSession(qrCode: code)?.verify() == false)
    }
}

/// A browser extension's pairing code: `1:<sessionId>:<pkPersHex>:<pkEpheHex>:<signatureHex>`, base64-encoded,
/// the signature over `sessionId‖pkPersHex‖pkEpheHex` by the persistent key.
private enum ConnectSessionFixture {

    static func qrCode(valid: Bool = true) -> String {
        let persistentKey = P256.Signing.PrivateKey()
        let ephemeralKey = P256.Signing.PrivateKey()
        let sessionId = UUID().uuidString.lowercased()
        let pkPersHex = persistentKey.publicKey.compressedRepresentation.hexEncodedString()
        let pkEpheHex = ephemeralKey.publicKey.compressedRepresentation.hexEncodedString()
        let message = "\(sessionId)\(pkPersHex)\(pkEpheHex)".data(using: .utf8)!
        var signature = try! persistentKey.signature(for: message).rawRepresentation
        if valid == false {
            signature[0] ^= 0xFF
        }
        let payload = "1:\(sessionId):\(pkPersHex):\(pkEpheHex):\(signature.hexEncodedString())"
        return Data(payload.utf8).base64EncodedString()
    }
}
