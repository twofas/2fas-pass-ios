// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

public extension UIView {
    func pinToParent(flexibleBottom: Bool = false) {
        guard let s = superview else {
            Log("No parent view available")
            return
        }
        
        translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: s.topAnchor),
            leftAnchor.constraint(equalTo: s.leftAnchor),
            rightAnchor.constraint(equalTo: s.rightAnchor)
        ])
        
        if flexibleBottom {
            bottomAnchor.constraint(lessThanOrEqualTo: s.bottomAnchor).isActive = true
        } else {
            bottomAnchor.constraint(equalTo: s.bottomAnchor).isActive = true
        }
    }
    
    func pinToParentSafeAnchors() {
        guard let s = superview else {
            Log("No parent view available")
            return
        }
        
        translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: s.safeTopAnchor),
            leftAnchor.constraint(equalTo: s.leftAnchor),
            rightAnchor.constraint(equalTo: s.rightAnchor),
            bottomAnchor.constraint(equalTo: s.safeBottomAnchor)
        ])
    }
    
    func pinToParent(with margin: UIEdgeInsets) {
        guard let s = superview else {
            Log("No parent view available")
            return
        }
        
        translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: s.topAnchor, constant: margin.top),
            leadingAnchor.constraint(equalTo: s.leadingAnchor, constant: margin.left),
            trailingAnchor.constraint(equalTo: s.trailingAnchor, constant: -margin.right),
            bottomAnchor.constraint(equalTo: s.bottomAnchor, constant: -margin.bottom)
        ])
    }
    
    func pinContentToScrollView(withTopMargin topMargin: CGFloat) {
        pinToParentMargin(withInsets: UIEdgeInsets(top: topMargin, left: 0, bottom: 0, right: 0), flexibleBottom: true)
    }
    
    func pinToParentMargin(withInsets insets: UIEdgeInsets = UIEdgeInsets.zero, flexibleBottom: Bool = false) {
        guard let s = superview else {
            
            Log("No parent view available")
            return
        }
        
        translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            topAnchor.constraint(equalTo: s.layoutMarginsGuide.topAnchor, constant: insets.top),
            leadingAnchor.constraint(equalTo: s.layoutMarginsGuide.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: s.layoutMarginsGuide.trailingAnchor, constant: insets.right)
        ])
        
        if flexibleBottom {
            bottomAnchor.constraint(
                lessThanOrEqualTo: s.layoutMarginsGuide.bottomAnchor,
                constant: insets.bottom
            ).isActive = true
        } else {
            bottomAnchor.constraint(
                equalTo: s.layoutMarginsGuide.bottomAnchor,
                constant: insets.bottom
            ).isActive = true
        }
    }
    
    func pinToParentCenter() {
        guard let s = superview else {
            Log("No parent view available")
            return
        }
        
        translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            centerXAnchor.constraint(equalTo: s.centerXAnchor),
            centerYAnchor.constraint(equalTo: s.centerYAnchor)
        ])
    }
    
    func pinToSafeAreaParentCenter() {
        guard let s = superview else {
            Log("No parent view available")
            return
        }
        
        translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            centerXAnchor.constraint(equalTo: s.safeAreaLayoutGuide.centerXAnchor),
            centerYAnchor.constraint(equalTo: s.safeAreaLayoutGuide.centerYAnchor)
        ])
    }
    
    func shake() {
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)
        animation.duration = 0.6
        animation.values = [-20, 20, -20, 20, -10, 10, -5, 5, 0]
        layer.add(animation, forKey: "shake")
    }
    
    static func prepareViewsForAutoLayout(withViews views: [UIView], superview: UIView?) {
        views.forEach { $0.translatesAutoresizingMaskIntoConstraints = false }
        
        guard let s = superview else { return }
        
        views.forEach { s.addSubview($0) }
    }
    
    func overlay(_ view: UIView, on overlayed: UIView) {
        addSubview(view, with: [
            view.leadingAnchor.constraint(equalTo: overlayed.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: overlayed.trailingAnchor),
            view.topAnchor.constraint(equalTo: overlayed.topAnchor),
            view.bottomAnchor.constraint(equalTo: overlayed.bottomAnchor)
        ])
    }
    
    func addSubview(_ v: UIView, with constraints: [NSLayoutConstraint]) {
        v.translatesAutoresizingMaskIntoConstraints = false
        addSubview(v)
        NSLayoutConstraint.activate(constraints)
    }

    var safeTopAnchor: NSLayoutYAxisAnchor { self.safeAreaLayoutGuide.topAnchor }
    var safeLeadingAnchor: NSLayoutXAxisAnchor { self.safeAreaLayoutGuide.leadingAnchor }
    var safeTrailingAnchor: NSLayoutXAxisAnchor { self.safeAreaLayoutGuide.trailingAnchor }
    var safeBottomAnchor: NSLayoutYAxisAnchor { self.safeAreaLayoutGuide.bottomAnchor }
    
    func removeAllSubviews() {
        subviews.forEach { $0.removeFromSuperview() }
    }
}

