// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI

final class ChangeProtectionLevelViewController: UIViewController {
    var presenter: ChangeProtectionLevelPresenter!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationItem.title = String(localized: .loginSecurityLevelLabel)
        
        let vc = UIHostingController(rootView: ChangeProtectionLevelView(presenter: presenter))
        placeChild(vc)
    }
}
