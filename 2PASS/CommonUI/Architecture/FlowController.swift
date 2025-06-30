// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

open class FlowController {
    public private(set) weak var _viewController: UIViewController!

    public init(viewController: UIViewController) {
        self._viewController = viewController
    }
}
