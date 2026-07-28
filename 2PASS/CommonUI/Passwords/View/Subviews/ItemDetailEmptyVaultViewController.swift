// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI
import Common

/// Shown in the detail column of the items split view when the vault is empty, so the full
/// "no items" empty screen occupies the wide detail column instead of the narrow list column.
final class ItemDetailEmptyVaultViewController: UIViewController {

    private let onQuickSetup: Callback

    init(onQuickSetup: @escaping Callback) {
        self.onQuickSetup = onQuickSetup
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        embedItemsDetailColumnContent(
            EmptyPasswordListView(onQuickSetup: { [weak self] in
                self?.onQuickSetup()
            })
        )
    }
}
