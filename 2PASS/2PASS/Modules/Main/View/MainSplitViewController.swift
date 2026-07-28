// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import CommonUI

/// The wide-layout split (sidebar | list | detail) hosted by `MainContainerViewController`. The
/// container owns the presenter, lifecycle and width-based switching; this controller just renders the
/// columns and forwards the Settings badge to the sidebar's footer item.
final class MainSplitViewController: UISplitViewController {

    /// Set by the coordinator to toggle the Settings footer item's badge.
    var onSetBadge: ((Bool) -> Void)?
}

extension MainSplitViewController: MainViewControlling {
    func showBadge() {
        onSetBadge?(true)
    }

    func hideBadge() {
        onSetBadge?(false)
    }
}
