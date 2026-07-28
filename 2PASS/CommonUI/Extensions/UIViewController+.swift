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

    /// True when this controller's window is regular in both size classes — the environments
    /// (full-screen iPad, wide multitasking window) with room for large centered sheets. Falls back
    /// to the controller's own traits when it isn't in a window yet. Use instead of
    /// `UIDevice.isiPad` for presentation-style decisions: a compact iPad multitasking window
    /// (1/3 Split View, Slide Over) correctly reads as not-regular and gets the compact treatment.
    var isInRegularSizedWindow: Bool {
        let traits = viewIfLoaded?.window?.traitCollection ?? traitCollection
        return traits.horizontalSizeClass == .regular && traits.verticalSizeClass == .regular
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

    /// Symmetric counterpart to `placeChild`: detaches this controller from its container in the
    /// documented order (`willMove` → view removal → `removeFromParent`). Safe on a controller
    /// that is only half-contained (e.g. an iOS 18 pop that removed the parent but left the view
    /// attached) — each step is a no-op where it doesn't apply.
    func unplaceFromParent() {
        willMove(toParent: nil)
        viewIfLoaded?.removeFromSuperview()
        removeFromParent()
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
