// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

public struct BiometricPromptRouter {
    
    public static func buildView(onClose: @escaping Callback) -> some View {
        BiometricPromptView(presenter: .init(interactor: ModuleInteractorFactory.shared.biometricPromptModuleInteractor(), onClose: onClose))
    }
}
