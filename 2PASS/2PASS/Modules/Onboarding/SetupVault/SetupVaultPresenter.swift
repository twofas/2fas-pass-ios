// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

enum SetupVaultRouteDestination: Identifiable {
    case generateSecretKey
    
    var id: String {
        switch self {
        case .generateSecretKey:
            return "generateSecretKey"
        }
    }
}

@Observable
final class SetupVaultPresenter {
    var destination: SetupVaultRouteDestination?
    
    func onGetStartedTap() {
        destination = .generateSecretKey
    }
}
