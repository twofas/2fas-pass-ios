// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

extension ToastPresenter {

    public func presentUsernameCopied() {
        presentCopied(T.toastUsernameCopied)
    }

    public func presentPasswordCopied() {
        presentCopied(T.toastPasswordCopied)
    }

    public func presentSecureNoteCopied() {
        presentCopied(T.toastSecureNoteCopied)
    }

    public func presentCardNumberCopied() {
        presentCopied(T.toastCardNumberCopied)
    }

    public func presentCardSecurityCodeCopied() {
        presentCopied(T.toastCardSecurityCodeCopied)
    }

    public func presentCopied() {
        presentCopied(T.commonCopied)
    }

    private func presentCopied(_ text: String) {
        present(
            text,
            style: .info,
            icon: UIImage(named: "copy.icon")?.withRenderingMode(.alwaysTemplate),
        )
    }
}
