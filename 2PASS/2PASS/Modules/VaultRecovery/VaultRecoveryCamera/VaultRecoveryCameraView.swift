// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct VaultRecoveryCameraView: View {
    
    @State
    private var errorReason: String?
    
    @State
    var presenter: VaultRecoveryCameraPresenter
    
    @Environment(\.dismiss)
    private var dismiss
    
    var body: some View {
        Group {
            if presenter.isCameraAvailable {
                ScanQRCodeCameraView(
                    title: Text(T.restoreQrCodeCameraTitle.localizedKey),
                    description: Text(T.restoreQrCodeCameraDescription.localizedKey),
                    codeFound: { code in
                        presenter.onFoundCode(code: code)
                    }
                )
            } else {
                Color.black
                    .ignoresSafeArea()
                    .overlay {
                        ErrorTextView(attributedString: reason)
                    }
            }
        }
        .onAppear {
            presenter.onAppear()
        }
        .onTapGesture {
            guard !presenter.isCameraAvailable else { return }
            presenter.onToAppSettings()
        }
        .overlay(alignment: .topTrailing) {
            CloseButton {
                dismiss()
            }
            .padding(20)
        }
        .colorScheme(.light)
    }
    
    private var reason: AttributedString {
        if let errorReason {
            return AttributedString(errorReason)
        }
        var result = AttributedString(T.restoreQrCodeError)
        if let range = result.range(of: T.restoreQrCodeErrorSystemSettings) {
            result[range].underlineStyle = .single
        }
        
        return result
    }
}

private struct ErrorTextView: View {
    let text: AttributedString
    
    init(attributedString: AttributedString) {
        self.text = attributedString
    }
    
    var body: some View {
        Text(text)
            .font(.headline)
            .foregroundColor(Color(Asset.mainInvertedTextColor.swiftUIColor))
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.l)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

#Preview {
    VaultRecoveryCameraView(presenter: .init(interactor: ModuleInteractorFactory.shared.vaultRecoveryCameraModuleInteractor(), onCompletion: { _, _ in }))
}
