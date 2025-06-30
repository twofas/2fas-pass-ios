// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct ScanQRCodeView: View {
    @State
    private var errorReason: String?
    
    @Bindable
    var presenter: EnterWordsPresenter
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .center, spacing: Spacing.m) {
                Group {
                    if presenter.isCameraAvailable {
                        CameraViewport(didRegisterError: { errorReason in
                            self.errorReason = errorReason
                        }, didFoundCode: { code in
                            presenter.onFoundCode(code: code)
                        }, cameraFreeze: $presenter.freezeCamera)
                    } else {
                        ErrorTextView(attributedString: reason)
                    }
                }
                .frame(height: CameraViewportMetrics.cameraActiveAreaHeight)
                .frame(maxWidth: .infinity)
                .background(Color.black)
                .cornerRadius(14)
                .onTapGesture {
                    guard !presenter.isCameraAvailable else { return }
                    presenter.onToAppSettings()
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        presenter.showScanQRCode = false
                    } label: {
                        Text(T.commonCancel.localizedKey)
                    }
                    
                }
            }
        }
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
