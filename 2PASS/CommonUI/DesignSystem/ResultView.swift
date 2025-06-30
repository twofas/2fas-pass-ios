// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

private struct Constants {
    static let iconFontSize = 54.0
}

public enum ResultViewKind {
    case success
    case failure
    case info
}

public struct ResultView<Action>: View where Action: View {
    
    let kind: ResultViewKind
    let title: Text
    let description: Text?
    let action: Action
    
    public init(kind: ResultViewKind, title: Text, description: Text? = nil, @ViewBuilder action: () -> Action) {
        self.kind = kind
        self.title = title
        self.description = description
        self.action = action()
    }
    
    public var body: some View {
        VStack(spacing: Spacing.xll) {
            Spacer()
            
            icon
                .font(.system(size: Constants.iconFontSize))
            
            VStack(spacing: Spacing.s) {
                title
                    .font(.title1Emphasized)
                    .foregroundStyle(.neutral950)
                
                description
                    .font(.subheadline)
                    .foregroundStyle(.neutral600)
            }
            
            Spacer()
            
            action
                .buttonStyle(.filled)
                .controlSize(.large)
                .multilineTextAlignment(.center)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, Spacing.xl)
        .navigationBarBackButtonHidden()
        .readableContentMargins()
    }
    
    private var icon: some View {
        switch kind {
        case .success:
            Image(systemName: "checkmark.circle")
                .foregroundStyle(.brand500)
        case .failure:
            Image(systemName: "xmark.circle")
                .foregroundStyle(.danger500)
        case .info:
            Image(systemName: "info.circle")
                .foregroundStyle(.brand500)
        }
    }
}

#Preview {
    ResultView(kind: .success, title: Text("Title"), description: Text("Description"), action: {
        Button("common_continue") {}
    })
}
