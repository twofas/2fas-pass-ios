// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CommonUI
import Common

enum ConnectIntroDestination: RouterDestination {
    case permissions(onFinish: Callback)
    
    var id: String {
        switch self {
        case .permissions: "permissions"
        }
    }
}

@Observable
final class ConnectIntroPresenter {
    
    var destination: ConnectIntroDestination?
    
    let learnMoreURL = URL(string: "https://2fas.com/pass/mobile-be")!
    let onContinue: Callback
    
    init(onContinue: @escaping Callback) {
        self.onContinue = onContinue
    }
}
