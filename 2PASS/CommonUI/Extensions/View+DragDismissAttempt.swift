// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public extension View {

    /// Intercepts the user's swipe-down gesture on a presented sheet and
    /// calls `onAttempt` instead of dismissing.
    ///
    /// Toggle `isEnabled` dynamically — for example, bind it to a "has
    /// unsaved changes" flag so the sheet dismisses freely when clean and
    /// asks for confirmation only when dirty.
    ///
    /// ```swift
    /// .dragDismissAttempt(isEnabled: hasUnsavedChanges) {
    ///     isDiscardConfirmationPresented = true
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - isEnabled: When `true`, interactive dismissal is blocked and
    ///     `onAttempt` fires on a swipe-down. When `false`, the sheet
    ///     dismisses normally.
    ///   - onAttempt: Called on the main actor when the user tries to
    ///     dismiss the sheet while `isEnabled` is `true`.
    func dragDismissAttempt(isEnabled: Bool, onAttempt: @escaping () -> Void) -> some View {
        background(DragDismissAttemptCatcher(isEnabled: isEnabled, onAttempt: onAttempt))
    }
}

private struct DragDismissAttemptCatcher: UIViewControllerRepresentable {
    let isEnabled: Bool
    let onAttempt: () -> Void

    func makeUIViewController(context: Context) -> Controller {
        Controller()
    }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.update(isEnabled: isEnabled, onAttempt: onAttempt)
    }

    static func dismantleUIViewController(_ controller: Controller, coordinator: ()) {
        controller.uninstall()
    }

    final class Controller: UIViewController, UIAdaptivePresentationControllerDelegate {
        private var onAttempt: () -> Void = {}
        private var isEnabled = false
        private weak var presentedTarget: UIViewController?
        private weak var originalDelegate: (any UIAdaptivePresentationControllerDelegate)?

        override func loadView() {
            view = UIView()
            view.backgroundColor = .clear
            view.isUserInteractionEnabled = false
        }

        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)
            installIfNeeded()
            applyModalState()
        }

        func update(isEnabled: Bool, onAttempt: @escaping () -> Void) {
            self.onAttempt = onAttempt
            self.isEnabled = isEnabled
            installIfNeeded()
            applyModalState()
        }

        func uninstall() {
            if let target = presentedTarget,
               let presentationController = target.presentationController,
               presentationController.delegate === self {
                presentationController.delegate = originalDelegate
            }
            presentedTarget?.isModalInPresentation = false
            presentedTarget = nil
            originalDelegate = nil
        }

        private func installIfNeeded() {
            guard presentedTarget == nil else { return }
            guard let target = findPresentedAncestor() else { return }
            presentedTarget = target
            if let presentationController = target.presentationController {
                originalDelegate = presentationController.delegate
                presentationController.delegate = self
            }
        }

        private func applyModalState() {
            presentedTarget?.isModalInPresentation = isEnabled
        }

        private func findPresentedAncestor() -> UIViewController? {
            var current: UIViewController? = parent
            var lastPresented: UIViewController? = nil
            while let viewController = current {
                if viewController.presentingViewController != nil {
                    lastPresented = viewController
                }
                current = viewController.parent
            }
            return lastPresented
        }

        // MARK: - Delegate forwarding

        override func responds(to aSelector: Selector!) -> Bool {
            super.responds(to: aSelector) || (originalDelegate?.responds(to: aSelector) ?? false)
        }

        override func forwardingTarget(for aSelector: Selector!) -> Any? {
            originalDelegate
        }

        // MARK: - UIAdaptivePresentationControllerDelegate

        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
            onAttempt()
            originalDelegate?.presentationControllerDidAttemptToDismiss?(presentationController)
        }
    }
}
