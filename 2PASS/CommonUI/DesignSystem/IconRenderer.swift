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
    private let contentTypeRenderer = ContentTypeRenderer()
    
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
        
        addSubview(contentTypeRenderer)
        contentTypeRenderer.pinToParentCenter()
    }
    
    func configure(with iconType: ItemCellData.Icon, name: String) {
        func showLabel(labelTitle: String, labelColor: UIColor?) {
            imageRenderer.setImage(nil)
            contentTypeRenderer.configure(with: nil)
            
            labelRenderer.setColor(labelColor, animated: false)
            labelRenderer.setText(labelTitle)
            
            imageRenderer.isHidden = true
            contentTypeRenderer.isHidden = true
            labelRenderer.isHidden = false
        }
        
        switch iconType {
        case .login(let iconType):
            switch iconType {
            case .customIcon, .domainIcon:
                showLabel(labelTitle: Config.defaultIconLabel(forName: name), labelColor: nil)
            case .label(let labelTitle, let labelColor):
                showLabel(labelTitle: labelTitle, labelColor: labelColor)
            }
        case .contentType(let contentType):
            contentTypeRenderer.configure(with: contentType)

            imageRenderer.isHidden = true
            labelRenderer.isHidden = true
            contentTypeRenderer.isHidden = false
        case .paymentCard(let issuer):
            if let issuer, let paymentCardIssuer = PaymentCardIssuer(rawValue: issuer) {
                updateIcon(with: paymentCardIssuer.icon, ignoreCornerRadius: true)
            } else {
                contentTypeRenderer.configure(with: .paymentCard)

                imageRenderer.isHidden = true
                labelRenderer.isHidden = true
                contentTypeRenderer.isHidden = false
            }
        }
    }
    
    func updateIcon(with image: UIImage, ignoreCornerRadius: Bool = false) {
        imageRenderer.setImage(image, ignoreCornerRadius: ignoreCornerRadius)
        imageRenderer.isHidden = false
        contentTypeRenderer.isHidden = true
        labelRenderer.isHidden = true
    }
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: Config.iconDimension, height: Config.iconDimension)
    }
}
