// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI

final class EnterWordsViewController: UIViewController {
    var presenter: EnterWordsPresenter!
    
    override func viewDidLoad() {
        super.viewDidLoad()
                
        let vc = UIHostingController(rootView: EnterWordsView(presenter: presenter))
        placeChild(vc)
    }
}
