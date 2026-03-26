// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CryptoKit

/// Encapsulates WebAuthn cryptographic operations using CryptoKit P-256 (ES256).
public enum PasskeyCryptoService {

    public struct KeyPair {
        public let credentialID: Data
        public let privateKeyDER: Data
        public let publicKeyCOSE: Data
    }

    // MARK: - Key Generation

    /// Generates a new P-256 key pair for passkey registration.
    /// - Returns: A `KeyPair` with 32-byte random credential ID, raw private key, and CBOR-encoded COSE public key.
    public static func generateKeyPair() -> KeyPair {
        var credentialID = Data(count: 32)
        credentialID.withUnsafeMutableBytes { buffer in
            _ = SecRandomCopyBytes(kSecRandomDefault, 32, buffer.baseAddress!)
        }

        let privateKey = P256.Signing.PrivateKey()
        let publicKey = privateKey.publicKey
        let rawPublicKey = publicKey.x963Representation
        // x963 format: 0x04 || x (32 bytes) || y (32 bytes)
        let x = rawPublicKey[1...32]
        let y = rawPublicKey[33...64]

        // COSE key: {1:2, 3:-7, -1:1, -2:x, -3:y}
        // 1 (kty) = 2 (EC2), 3 (alg) = -7 (ES256), -1 (crv) = 1 (P-256)
        let coseKey = CBOREncoder.encode(.map([
            (.unsignedInt(1), .unsignedInt(2)),
            (.unsignedInt(3), .negativeInt(-7)),
            (.negativeInt(-1), .unsignedInt(1)),
            (.negativeInt(-2), .byteString(Data(x))),
            (.negativeInt(-3), .byteString(Data(y))),
        ]))

        return KeyPair(
            credentialID: credentialID,
            privateKeyDER: privateKey.derRepresentation,
            publicKeyCOSE: coseKey
        )
    }

    // MARK: - Registration (Attestation)

    /// Builds authenticator data for a registration (attestation) response.
    public static func buildRegistrationAuthenticatorData(
        rpID: String,
        credentialID: Data,
        publicKeyCOSE: Data
    ) -> Data {
        var authData = Data()

        // rpIdHash: SHA-256 of the relying party ID
        let rpIdHash = SHA256.hash(data: Data(rpID.utf8))
        authData.append(contentsOf: rpIdHash)

        // flags: UP (0x01) | UV (0x04) | BE (0x08) | BS (0x10) | AT (0x40) = 0x5D
        // BE+BS are required for third-party credential providers (synced passkeys)
        authData.append(0x5D)

        // signCount: 4 bytes, zero (we don't track sign counts)
        authData.append(contentsOf: [0, 0, 0, 0] as [UInt8])

        // attestedCredentialData:
        //   AAGUID (16 bytes zero – software authenticator)
        authData.append(contentsOf: [UInt8](repeating: 0, count: 16))
        //   credentialIdLength (2 bytes big-endian)
        let idLen = UInt16(credentialID.count)
        authData.append(UInt8(idLen >> 8))
        authData.append(UInt8(idLen & 0xFF))
        //   credentialId
        authData.append(credentialID)
        //   credentialPublicKey (COSE)
        authData.append(publicKeyCOSE)

        return authData
    }

    /// Builds a "none" attestation object wrapping the authenticator data.
    public static func buildAttestationObject(authenticatorData: Data) -> Data {
        CBOREncoder.encode(.map([
            (.textString("fmt"), .textString("none")),
            (.textString("attStmt"), .map([])),
            (.textString("authData"), .byteString(authenticatorData)),
        ]))
    }

    // MARK: - Authentication (Assertion)

    /// Builds authenticator data for an assertion response.
    public static func buildAssertionAuthenticatorData(rpID: String) -> Data {
        var authData = Data()

        let rpIdHash = SHA256.hash(data: Data(rpID.utf8))
        authData.append(contentsOf: rpIdHash)

        // flags: UP (0x01) | UV (0x04) | BE (0x08) | BS (0x10) = 0x1D
        // BE+BS are required for third-party credential providers (synced passkeys)
        authData.append(0x1D)

        // signCount: 4 bytes, zero
        authData.append(contentsOf: [0, 0, 0, 0] as [UInt8])

        return authData
    }

    /// Signs `authenticatorData || clientDataHash` with the given DER-encoded P-256 private key.
    /// - Returns: DER-encoded ECDSA signature.
    public static func sign(
        authenticatorData: Data,
        clientDataHash: Data,
        privateKeyDER: Data
    ) throws -> Data {
        let privateKey = try P256.Signing.PrivateKey(derRepresentation: privateKeyDER)
        var signedData = authenticatorData
        signedData.append(clientDataHash)
        let signature = try privateKey.signature(for: signedData)
        return signature.derRepresentation
    }
}
