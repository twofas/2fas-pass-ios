// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

open class CommonNavigationController: UINavigationController {
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        
        let shadowLine = Asset.shadowLine.image
            .withRenderingMode(.alwaysTemplate)
            .resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: .tile)
        
        let scrollEdgeAppearance = makeNavigationBarAppearance()
        navigationBar.scrollEdgeAppearance = scrollEdgeAppearance
        
        let standardAppearance = makeNavigationBarAppearance()
        standardAppearance.backgroundColor = Asset.mainBackgroundColor.color
        standardAppearance.shadowImage = shadowLine
        standardAppearance.shadowColor = Asset.dividerColor.color
        navigationBar.standardAppearance = standardAppearance
        
        navigationBar.prefersLargeTitles = true
    }
}

extension CommonNavigationController {
    
    private func makeNavigationBarAppearance() -> UINavigationBarAppearance {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.titleTextAttributes = [.foregroundColor: Asset.mainTextColor.color]
        appearance.largeTitleTextAttributes = [.foregroundColor: Asset.mainTextColor.color]
        return appearance
    }
}
