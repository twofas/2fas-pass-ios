// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

public final class CommonNavigationControllerFlow<T: NavigationFlowController>: CommonNavigationController {
    public private(set) var flowController: T!
    
    public convenience init(flowController: T) {
        self.init()
        self.flowController = flowController
    }
}
