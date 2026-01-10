// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common

private struct Constants {
    static let mainAnimationMaxHeight = 328.0
}

struct ConnectIntroView: View {
    
    @State
    var presenter: ConnectIntroPresenter
    
    @Environment(\.openURL)
    private var openURL
    
    var body: some View {
        VStack(spacing: Spacing.l) {
            LottieSchemedAnimationView(baseNamed: "ios-onboarding-03") {
                $0.looping()
                    .frame(minHeight: 0, maxHeight: Constants.mainAnimationMaxHeight)
            }
            .frame(maxWidth: .infinity)
            .background {
                Color.neutral50
                    .ignoresSafeArea()
            }
            
            VStack(spacing: Spacing.xll) {
                Text(.connectIntroHeader)
                    .font(.title2Emphasized)
                    .foregroundStyle(.neutral950)
                
                Button {
                    openURL(presenter.learnMoreURL)
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Text(.connectIntroLearnMoreCta)
                        Image(systemName: "arrow.up.right")
                    }
                }
                .buttonStyle(.bezeledGray(fillSpace: false))
                .controlSize(.small)
            }
            .padding(.horizontal, Spacing.xl)
            .multilineTextAlignment(.center)
            .readableContentMargins()
            
            Spacer()
            
            Button(.commonContinue) {
                presenter.onContinue()
            }
            .buttonStyle(.filled)
            .controlSize(.large)
            .padding(.horizontal, Spacing.xl)
            .padding(.vertical, Spacing.l)
            .readableContentMargins()
        }
        .router(router: ConnectIntroRouter(), destination: $presenter.destination)
    }
}

#Preview {
    ConnectIntroView(presenter: .init(onContinue: {}))
}
