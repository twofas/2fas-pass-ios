// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

extension ToastPresenter {

    public func presentUsernameCopied() {
        presentCopied(.toastUsernameCopied)
    }

    public func presentPasswordCopied() {
        presentCopied(.toastPasswordCopied)
    }

    public func presentSecureNoteCopied() {
        presentCopied(.toastSecureNoteCopied)
    }

    public func presentPaymentCardNumberCopied() {
        presentCopied(.toastCardNumberCopied)
    }

    public func presentPaymentCardSecurityCodeCopied() {
        presentCopied(.toastCardSecurityCodeCopied)
    }

    public func presentCopied() {
        presentCopied(.commonCopied)
    }

    private func presentCopied(_ text: LocalizedStringResource) {
        present(
            text,
            style: .info,
            icon: UIImage(named: "copy.icon")?.withRenderingMode(.alwaysTemplate),
        )
    }
}
