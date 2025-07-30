// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

public extension UIViewController {
    
    var topViewController: UIViewController {
        var top = self
        while let presented = top.presentedViewController {
            top = presented
        }
        return top
    }
    
    func configureAsModal() {
        modalPresentationStyle = .formSheet
        isModalInPresentation = true
        definesPresentationContext = true
    }
    
    func configureAsLargeModal() {
        modalPresentationStyle = .pageSheet
        isModalInPresentation = true
        definesPresentationContext = true
    }
    
    func placeChild(_ vc: UIViewController, container: UIView? = nil) {
        vc.willMove(toParent: self)
        addChild(vc)
        if let container {
            container.addSubview(vc.view)
        } else {
            view.addSubview(vc.view)
        }
        vc.view.pinToParent()
        vc.didMove(toParent: self)
    }

    func configureAsPhoneFullScreenModal() {
        if UIDevice.isiPad {
            modalPresentationStyle = .formSheet
        } else {
            modalPresentationStyle = .fullScreen
        }
        isModalInPresentation = true
        definesPresentationContext = true
    }
    
    func configureAsFullScreenModal() {
        modalPresentationStyle = .fullScreen
        isModalInPresentation = true
        definesPresentationContext = true
    }
    
    // Keyboard Safe Area adjustment
    
    func startSafeAreaKeyboardAdjustment() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onKeyboardFrameWillChangeNotificationReceived(_:)),
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }
    
    func stopSafeAreaKeyboardAdjustment() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIResponder.keyboardWillChangeFrameNotification,
            object: nil
        )
    }
    
    @objc
    private func onKeyboardFrameWillChangeNotificationReceived(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        else { return }
        
        let keyboardFrameInView = view.convert(keyboardFrame, from: nil)
        let safeAreaFrame = view.safeAreaLayoutGuide.layoutFrame.insetBy(dx: 0, dy: -additionalSafeAreaInsets.bottom)
        let intersection = safeAreaFrame.intersection(keyboardFrameInView)
        
        let keyboardAnimationDuration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber
        let animationDuration: TimeInterval = keyboardAnimationDuration?.doubleValue ?? 0
        let animationCurveRawNSN = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber
        let animationCurveRaw = animationCurveRawNSN?.uintValue ?? UIView.AnimationOptions.curveEaseInOut.rawValue
        let animationCurve = UIView.AnimationOptions(rawValue: animationCurveRaw)
        
        UIView.animate(
            withDuration: animationDuration,
            delay: 0,
            options: animationCurve,
            animations: { [weak self] in
                self?.additionalSafeAreaInsets.bottom = intersection.height
                self?.view.layoutIfNeeded()
            },
            completion: nil
        )
    }
}
