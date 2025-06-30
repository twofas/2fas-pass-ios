// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

private struct Constants {
    static let cornerRadius: CGFloat = 12
    static let innerIconDimension = 28
    static let innerCornerRadius: CGFloat = 6
}

final class ImageIconRenderer: UIView {
    
    private let imageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        return view
    }()
    
    private let backgroundImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        
        let effect = UIBlurEffect(style: .prominent)
        let backgroundBlurView = UIVisualEffectView(effect: effect)
        backgroundBlurView.translatesAutoresizingMaskIntoConstraints = false
        imageView.addSubview(backgroundBlurView)
        backgroundBlurView.pinToParent()
        
        imageView.layer.cornerRadius = Constants.cornerRadius
        imageView.clipsToBounds = true
        
        return imageView
    }()
    
    var image: UIImage? {
        didSet {
            imageView.image = image
            backgroundImageView.image = image
        }
    }
        
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        backgroundImageView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(backgroundImageView)
        backgroundImageView.pinToParentCenter()
        
        NSLayoutConstraint.activate([
            backgroundImageView.widthAnchor.constraint(equalToConstant: CGFloat(Config.iconDimension)),
            backgroundImageView.heightAnchor.constraint(equalToConstant: CGFloat(Config.iconDimension))
        ])
        
        imageView.layer.cornerRadius = Constants.innerCornerRadius
        imageView.clipsToBounds = true
        
        addSubview(imageView)
        imageView.pinToParentCenter()
        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: CGFloat(Constants.innerIconDimension)),
            imageView.heightAnchor.constraint(equalToConstant: CGFloat(Constants.innerIconDimension))
        ])
    }
}
