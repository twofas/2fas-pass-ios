// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

private struct Constants {
    static let imageSize = 260.0
    static let imageMaxHeight = 260.0
    static let imageTopPadding = 20.0
    static let imageCornerRadius = 16.0
    static let imageStrokeWidth = 0.5
}

struct ForgotMasterPasswordView: View {

    @State var presenter: ForgotMasterPasswordPresenter

    @Environment(\.dismiss)
    private var dismiss
    
    @Environment(\.colorScheme)
    private var colorScheme

    var body: some View {
        VStack(spacing: Spacing.xll) {
            Image(.vaultDecryptionKitFullDocument)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: Constants.imageMaxHeight)
                .frame(width: Constants.imageSize)
                .padding(.top, Constants.imageTopPadding)
                .background {
                    RoundedRectangle(cornerRadius: Constants.imageCornerRadius)
                        .fill(.neutral50)
                        .stroke(colorScheme == .dark ? .neutral200 : .neutral100, lineWidth: Constants.imageStrokeWidth)
                }
            
            HeaderContentView(
                title: Text(.lockScreenForgotMasterPassword),
                subtitle: Text(.lockScreenForgotMasterPasswordDescription)
            )
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.m)
            
            SelectDecryptionMethod(
                onFiles: {},
                onCamera: {}
            )
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, Spacing.m)
        .router(router: ForgotMasterPasswordRouter(), destination: $presenter.destination)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                ToolbarCancelButton {
                    dismiss()
                }
            }
        }
        .onAppear {
            presenter.onAppear()
        }
    }
}

#Preview {
    ForgotMasterPasswordRouter.buildView()
}
