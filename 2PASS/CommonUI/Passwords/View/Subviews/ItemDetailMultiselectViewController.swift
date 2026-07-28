// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI

/// Shown in the detail column of the items split view while multiselecting in the list column.
/// It reports how many items are currently selected, replacing the per-item detail (and the
/// selection count that the standalone layout shows in its navigation title).
final class ItemDetailMultiselectViewController: UIViewController {

    @Observable
    fileprivate final class Model {
        var selectedCount: Int

        init(selectedCount: Int) {
            self.selectedCount = selectedCount
        }
    }

    private let model: Model

    init(selectedCount: Int) {
        self.model = Model(selectedCount: selectedCount)
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        embedItemsDetailColumnContent(MultiselectCountView(model: model))
    }

    /// Updates the displayed count in place so live selection changes don't reinstantiate the detail.
    func update(selectedCount: Int) {
        model.selectedCount = selectedCount
    }
}

private struct MultiselectCountView: View {

    let model: ItemDetailMultiselectViewController.Model

    var body: some View {
        EmptyListView(
            Text(.homeMultiselectDetailCount(Int32(model.selectedCount))),
            icon: Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 50))
        )
    }
}
