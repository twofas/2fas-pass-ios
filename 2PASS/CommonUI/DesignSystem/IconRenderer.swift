// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

final class IconRenderer: UIView {
    
    private let imageRenderer = ImageIconRenderer()
    private let labelRenderer = LabelRenderer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        setContentHuggingPriority(.defaultHigh + 2, for: .horizontal)
        setContentHuggingPriority(.defaultLow - 2, for: .vertical)
        
        addSubview(imageRenderer)
        imageRenderer.pinToParentCenter()
        
        addSubview(labelRenderer)
        labelRenderer.pinToParentCenter()
    }
    
    func configure(with iconType: PasswordIconType, name: String) {
        func showLabel(labelTitle: String, labelColor: UIColor?) {
            imageRenderer.image = nil
            
            labelRenderer.setColor(labelColor, animated: false)
            labelRenderer.setText(labelTitle)
            
            imageRenderer.isHidden = true
            labelRenderer.isHidden = false
        }
        
        switch iconType {
        case .customIcon, .domainIcon:
            showLabel(labelTitle: Config.defaultIconLabel(forName: name), labelColor: nil)
        case .label(let labelTitle, let labelColor):
            showLabel(labelTitle: labelTitle, labelColor: labelColor)
        }
    }
    
    func updateIcon(with data: Data) {
        guard let image = UIImage(data: data) else {
            return
        }
        imageRenderer.image = image
        imageRenderer.isHidden = false
        labelRenderer.isHidden = true
    }
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: Config.iconDimension, height: Config.iconDimension)
    }
}
