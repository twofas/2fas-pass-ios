// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

extension UIApplication {
    func openInBrowser(_ url: URL) {
        if url.scheme != nil {
            open(url)
        } else if let addedScheme = URL(string: "https://\(url.absoluteString)") {
            open(addedScheme)
        }
    }
}
