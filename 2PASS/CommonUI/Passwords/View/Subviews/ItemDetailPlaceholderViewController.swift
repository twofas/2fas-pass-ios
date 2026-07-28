// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI

/// Shown in the detail column of the items split view when the list is empty
/// and there is nothing to auto-select.
final class ItemDetailPlaceholderViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        embedItemsDetailColumnContent(
            EmptyListView(
                Text(.itemDetailEmptyPlaceholder),
                icon: Image(systemName: "lock.rectangle")
                    .font(.system(size: 50))
            )
        )
    }
}

extension UIViewController {
    /// Standard chrome shared by the detail column's hosted-SwiftUI screens (placeholder, empty
    /// vault, multiselect count): opaque main background, no large title, and a clear-background
    /// hosting child pinned to the whole view.
    func embedItemsDetailColumnContent(_ rootView: some View) {
        view.backgroundColor = UIColor(resource: .mainBackground)
        navigationItem.largeTitleDisplayMode = .never

        let host = UIHostingController(rootView: rootView)
        host.view.backgroundColor = .clear
        placeChild(host)
    }
}
