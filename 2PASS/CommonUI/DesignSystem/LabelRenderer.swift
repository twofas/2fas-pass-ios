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
        view.layer.cornerRadius = 16
        view.clipsToBounds = true
        return view
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textColor = UIColor(resource: .mainText)
        label.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        label.numberOfLines = 1
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        return label
    }()
        
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
        roundedRectangle.backgroundColor = color ?? ItemContentType.login.secondaryColor
        
        if let color {
            titleLabel.textColor = color.isDark ? .white : .black
        } else {
            titleLabel.textColor = ItemContentType.login.primaryColor
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
