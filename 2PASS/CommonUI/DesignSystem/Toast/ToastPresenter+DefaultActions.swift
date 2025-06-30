// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

extension ToastPresenter {
    
    public func presentUsernameCopied() {
        present(
            T.toastUsernameCopied,
            style: .info,
            icon: UIImage(named: "copy.icon")?.withRenderingMode(.alwaysTemplate),
        )
    }
    
    public func presentPasswordCopied() {
        present(
            T.toastPasswordCopied,
            style: .info,
            icon: UIImage(named: "copy.icon")?.withRenderingMode(.alwaysTemplate),
        )
    }
    
    public func presentCopied() {
        present(
            T.commonCopied,
            style: .info,
            icon: UIImage(named: "copy.icon")?.withRenderingMode(.alwaysTemplate),
        )
    }
}
