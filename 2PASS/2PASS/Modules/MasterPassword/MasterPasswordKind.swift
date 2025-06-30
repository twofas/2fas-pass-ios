// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Data
import Common

enum MasterPasswordKind: Equatable {
    static func == (lhs: MasterPasswordKind, rhs: MasterPasswordKind) -> Bool {
        switch (lhs, rhs) {
        case (.onboarding, .onboarding), (.change, .change), (.unencryptedVaultRecovery, .unencryptedVaultRecovery):
            return true
        default:
            return false
        }
    }
    
    case onboarding
    case change
    case unencryptedVaultRecovery(passwords: [PasswordData], tags: [ItemTagData])
}

extension MasterPasswordKind {
    var focusImmediately: Bool {
        switch self {
        case .onboarding: false
        case .change: true
        case .unencryptedVaultRecovery: true
        }
    }
    
    var header: String {
        switch self {
        case .unencryptedVaultRecovery, .onboarding: T.masterPasswordDefine
        case .change: T.masterPasswordCreateNew
        }
    }
    
    var setupEncryptionElements: Bool {
        switch self {
        case .onboarding: false
        case .change: false
        case .unencryptedVaultRecovery: true
        }
    }
}
