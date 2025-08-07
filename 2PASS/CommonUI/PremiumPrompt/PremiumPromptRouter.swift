// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public struct PremiumPromptRouter {
    
    public static func buildView(title: Text, description: Text) -> some View {
        PremiumPromptView(
            title: title,
            description: description,
            presenter: .init(
                interactor: ModuleInteractorFactory.shared.premiumPromptModuleInteractor()
            )
        )
    }
}
