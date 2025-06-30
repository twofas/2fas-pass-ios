// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

extension LabeledContentStyle where Self == NavigationLabeledContentStyle {
    
    static var navigationSettings: NavigationLabeledContentStyle {
        .init()
    }
}

struct NavigationLabeledContentStyle: LabeledContentStyle {
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
                .foregroundStyle(.neutral950)
            
            Spacer()
            
            HStack(spacing: Spacing.s) {
                configuration.content
                    .foregroundStyle(.neutral500)
                    .multilineTextAlignment(.trailing)
                
                Image(systemName: "chevron.right")
                    .foregroundStyle(.neutral400)
            }
        }
    }
}
