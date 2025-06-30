// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import CommonUI

enum ChangeSuccessDestination: RouterDestination {
    case vaultDecryptionKit(onFinish: Callback)
    
    var id: String {
        switch self {
        case .vaultDecryptionKit: "vaultDecryptionKit"
        }
    }
}

@Observable
final class ChangeSuccessPresenter {
    
    var destination: ChangeSuccessDestination?
    
    private let onFinish: Callback
    
    init(onFinish: @escaping Callback) {
        self.onFinish = onFinish
    }
    
    func onContinue() {
        destination = .vaultDecryptionKit(onFinish: onFinish)
    }
}
