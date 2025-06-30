// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct ConnectCommunicationContentView<Title, Description, Actions>: View where Title: View, Description: View, Actions: View {
    
    let iconColor: Color
    let title: Title
    let description: Description
    let actions: Actions
    
    init(iconColor: Color, title: Title, description: Description, @ViewBuilder actions: () -> Actions) {
        self.iconColor = iconColor
        self.title = title
        self.description = description
        self.actions = actions()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: Spacing.s) {
                title
                    .labelStyle(ConnectLabelStyle(iconColor: iconColor))
                
                description
                    .font(.subheadline)
                    .foregroundStyle(.neutral600)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            Spacer(minLength: Spacing.l)
            
            actions
                .controlSize(.large)
        }
    }
}

extension ConnectCommunicationContentView where Title == Label<Text, Image>, Description == Text {
    
    init(iconColor: Color, title: Title, desctiption: Text, @ViewBuilder actions: () -> Actions) {
        self.init(iconColor: iconColor, title: title, description: desctiption, actions: actions)
    }
}
