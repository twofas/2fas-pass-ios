// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

@available(iOS 26, *)
class EdgeEffectView: UIView {

    init(edge: UIRectEdge, scrollView: UIScrollView) {
        super.init(frame: .zero)
        
        let label = UILabel() // needed to display the edge effect
        addSubview(label)
        label.pinToParent()
        
        let interaction = UIScrollEdgeElementContainerInteraction()
        interaction.edge = edge
        interaction.scrollView = scrollView
        addInteraction(interaction)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
