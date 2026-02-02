// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

/// Protocol for parsing recovery kit QR codes.
/// This interactor handles QR code parsing logic shared between
/// VaultRecoveryCamera and ForgotMasterPasswordDecryptionKitCamera modules.
public protocol RecoveryKitScanCameraInteracting: AnyObject {
    /// Parses QR code contents for recovery kit data
    /// - Parameter str: The raw string from the QR code
    /// - Returns: Tuple of entropy and optional master key if valid, nil otherwise
    func parseQRCodeContents(_ str: String) -> (entropy: Entropy, masterKey: MasterKey?)?
}

public final class RecoveryKitScanCameraInteractor: RecoveryKitScanCameraInteracting {
    public init() {}

    public func parseQRCodeContents(_ str: String) -> (entropy: Entropy, masterKey: MasterKey?)? {
        guard let result = RecoveryKitLink.parse(from: str) else {
            return nil
        }
        let entropy = Data(base64Encoded: result.entropy)
        let masterKey: MasterKey? = {
            if let masterKey = result.masterKey {
                return Data(base64Encoded: masterKey)
            }
            return nil
        }()
        guard let entropy else {
            return nil
        }
        return (entropy: entropy, masterKey: masterKey)
    }
}
