// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

final class LabelRenderer: UIView {
    
    private let roundedRectangle: UIView = {
        let view = UIView()
        view.layer.cornerRadius = 12
        view.clipsToBounds = true
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = Asset.mainTextColor.color
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.numberOfLines = 1
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        return label
    }()
    
    private let gradientView = IconGradientView()
    
    private var accessibilityColor: String?
    private var accessibilityText: String?
    
    override init(frame: CGRect) {
        super.init(frame: CGRect(
            origin: .zero,
            size: CGSize(width: Config.iconDimension, height: Config.iconDimension)
        ))
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        addSubview(roundedRectangle)
        roundedRectangle.pinToParent()
        
        gradientView.translatesAutoresizingMaskIntoConstraints  = false
        roundedRectangle.addSubview(gradientView)
        gradientView.pinToParent()
        
        addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        let margin = Spacing.s
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: margin),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -margin)
        ])
                
        invalidateIntrinsicContentSize()
        isAccessibilityElement = true
    }
    
    func setColor(_ color: UIColor?, animated: Bool) {
        roundedRectangle.backgroundColor = color
        gradientView.isHidden = color != nil
        
        if let color {
            titleLabel.textColor = color.isDark ? .white : .black
        } else {
            titleLabel.textColor = UIColor.brand500
        }
        
        accessibilityColor = color?.accessibilityName
        updateAccessibility()
    }
    
    func setText(_ text: String) {
        titleLabel.text = text.twoLetters

        accessibilityText = text
        updateAccessibility()
    }
    
    private func updateAccessibility() {
        guard let text = accessibilityText, let color = accessibilityColor else { return }
        accessibilityLabel = "Service label with name \(text) and color \(color)"
    }
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: Config.iconDimension, height: Config.iconDimension)
    }
}

private final class RoundedRectangle: UIView {
    private let animKey = "fillColor"
    private var dimension: CGFloat = CGFloat(Config.iconDimension)
    
    override class var layerClass: AnyClass { CAShapeLayer.self }
    private var shapeLayer = CAShapeLayer()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    private func commonInit() {
        layer.addSublayer(shapeLayer)
    }
    
    override func layoutSubviews() {
        shapeLayer.path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: dimension, height: dimension)).cgPath
        
        super.layoutSubviews()
    }
    
    func setColor(_ color: UIColor) {
        shapeLayer.fillColor = color.cgColor
    }
}

final class IconGradientView: UIView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGradient()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGradient()
    }
    
    private func setupGradient() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(hexString: "#D1DEFA")!.cgColor,
            UIColor(hexString: "#C7D8FC")!.cgColor,
            UIColor(hexString: "#B9D0FF")!.cgColor
        ]
        
        gradientLayer.locations = [0.0, 0.5, 1.0]
        gradientLayer.startPoint = CGPoint(x: 1, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0, y: 1)
        gradientLayer.frame = bounds
        
        layer.insertSublayer(gradientLayer, at: 0)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        layer.sublayers?.first?.frame = bounds
    }
}
