// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

private struct Constants {
    static let imageMaxHeight = 260.0
    static let imageTopPadding = 20.0
    static let imageCornerRadius = 16.0
    static let imageStrokeWidth = 0.5
}

struct ForgotMasterPasswordView: View {

    @State var presenter: ForgotMasterPasswordPresenter
    
    @Environment(\.colorScheme)
    private var colorScheme

    var body: some View {
        VStack(spacing: Spacing.xll) {
            Image(.vaultDecryptionKitFullDocument)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: Constants.imageMaxHeight)
                .background {
                    RoundedRectangle(cornerRadius: Constants.imageCornerRadius)
                        .fill(.neutral50)
                        .stroke(colorScheme == .dark ? .neutral200 : .neutral100, lineWidth: Constants.imageStrokeWidth)
                }
            
            HeaderContentView(
                title: Text(.forgotMasterPasswordTitle),
                subtitle: Text(.forgotMasterPasswordDescription)
            )
            .padding(.top, Spacing.l)
            .padding(.bottom, Spacing.m)
            
            SelectDecryptionMethod(
                onFiles: { presenter.onFiles() },
                onCamera: { presenter.onCamera() }
            )
            
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.bottom, Spacing.m)
        .router(
            router: ForgotMasterPasswordRouter(),
            destination: $presenter.destination
        )
        .fileImporter(
            isPresented: $presenter.showFileImporter,
            allowedContentTypes: [.pdf, .png, .jpeg],
            onCompletion: { result in
                Task { @MainActor in
                    switch result {
                    case .success(let url): presenter.onFileOpen(url)
                    case .failure(let error): presenter.onFileError(error)
                    }
                }
            })
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                ToolbarCancelButton {
                    presenter.close()
                }
            }
        }
        .onAppear {
            presenter.onAppear()
        }
    }
}

#Preview {
    ForgotMasterPasswordRouter.buildView(
        config: .init(allowBiometrics: false, loginType: .login),
        onSuccess: {},
        onClose: {}
    )
}
