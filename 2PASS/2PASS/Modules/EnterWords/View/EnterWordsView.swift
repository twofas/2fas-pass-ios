// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct EnterWordsView: View {
    @Bindable
    var presenter: EnterWordsPresenter
    
    var body: some View {
        VStack {
            Text(T.restoreUseRecoveryKeyTitle.localizedKey)
                .font(.title)
            Spacer()
                .frame(maxHeight: .infinity)
            Text(T.restoreUseRecoveryKeyDescription)
            Spacer()
                .frame(maxHeight: .infinity)
            PrimaryButton(title: T.restoreQrCodeCameraTitle) {
                presenter.showScanQRCode = true
            }
            SecondaryButton(title: T.restoreEnterWordsTitle) {
                presenter.showEnterWords = true
            }
        }
        .padding(Spacing.m)
        .sheet(isPresented: $presenter.showEnterWords) {
            EnterWordsInputListView(presenter: presenter)
        }
        
        .sheet(isPresented: $presenter.showScanQRCode) {
            ScanQRCodeView(presenter: presenter)
        }
        .alert(T.restoreErrorIncorrectQrCode, isPresented: $presenter.showQRCodeError) {
            Button(T.commonOk.localizedKey) {
                presenter.handleResumeCamera()
            }
        }
        .alert(T.restoreErrorIncorrectWords, isPresented: $presenter.showIncorrectWordsError) {
            Button(T.commonOk.localizedKey) {
                presenter.handleResumeCamera()
            }
        }
        .alert(T.restoreErrorGeneral, isPresented: $presenter.showGeneralError) {
            Button(T.commonOk.localizedKey) {
                presenter.handleResumeCamera()
            }
        }
    }
}
