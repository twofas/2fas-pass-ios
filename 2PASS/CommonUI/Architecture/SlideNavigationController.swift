// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import UIKit

private struct Constants {
    static let keyboardHideWait: Duration = .milliseconds(500)
    static let slideDuration: TimeInterval = 0.5
}

/// One system-owned navigation stack whose screens are SwiftUI views; a `.slide` push keeps the
/// onboarding's slide transition and a transparent bar, a `.system` push is the plain UIKit one.
@MainActor
public final class SlideNavigationController: UINavigationController {

    private let decorate: (AnyView) -> AnyView
    private let keyboardObserver = KeyboardObserver()
    private var overlayController: UIViewController?

    // The stack as last shown; the screens missing from it after a transition were popped.
    private var shownControllers: [UIViewController] = []

    /// `decorate` wraps every hosted screen, root included (environment, tint, readers).
    public init<Root: View>(root: Root, decorate: @escaping (AnyView) -> AnyView) {
        self.decorate = decorate
        super.init(nibName: nil, bundle: nil)

        let rootScreen = host(AnyView(root), kind: .system)
        viewControllers = [rootScreen]
        shownControllers = [rootScreen]
        delegate = self
        setNavigationBarHidden(true, animated: false)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// A passthrough SwiftUI layer over the whole stack, pinned to the view's edges.
    public func setOverlay<Overlay: View>(_ overlay: Overlay) {
        overlayController?.unplaceFromParent()

        let controller = UIHostingController(rootView: overlay)
        controller.view.backgroundColor = .clear
        controller.view.isUserInteractionEnabled = false
        placeChild(controller)
        view.bringSubviewToFront(controller.view)
        overlayController = controller
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if let overlayView = overlayController?.view {
            view.bringSubviewToFront(overlayView)
        }
    }

    // MARK: - Hosting

    private func host(_ view: AnyView, kind: FlowPushKind) -> HostedScreen {
        let screen = HostedScreen(kind: kind)
        let action = FlowNavigationAction(
            push: { [weak self] view, kind, onPop in
                self?.push(view, kind: kind, onPop: onPop)
            },
            pop: { [weak self, weak screen] in
                guard let screen else { return }
                self?.pop(to: screen)
            }
        )
        screen.rootView = AnyView(
            decorate(view)
                .environment(\.flowNavigation, action)
                .onPreferenceChange(FlowBarTrailingItemPreferenceKey.self) { [weak screen] item in
                    screen?.trailingItem = item
                }
        )
        return screen
    }

    private func push(_ view: AnyView, kind: FlowPushKind, onPop: @escaping @MainActor () -> Void) {
        let screen = host(view, kind: kind)
        screen.onPop = onPop

        afterHidingKeyboard { [weak self] in
            guard let self else { return }

            // The back button a screen shows belongs to the item below it, so it is set before the push.
            topViewController?.navigationItem.backButtonDisplayMode = kind == .slide ? .minimal : .default
            pushViewController(screen, animated: true)
        }
    }

    private func pop(to screen: UIViewController) {
        afterHidingKeyboard { [weak self] in
            guard let self, viewControllers.contains(screen), topViewController !== screen else { return }
            popToViewController(screen, animated: true)
        }
    }

    private func afterHidingKeyboard(_ navigate: @escaping @MainActor () -> Void) {
        guard keyboardObserver.isKeyboardVisible else {
            navigate()
            return
        }

        UIApplication.shared.hideKeyboard()
        Task { @MainActor in
            try? await Task.sleep(for: Constants.keyboardHideWait)
            navigate()
        }
    }
}

extension SlideNavigationController: UINavigationControllerDelegate {

    public func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> (any UIViewControllerAnimatedTransitioning)? {
        let movingScreen = operation == .push ? toVC : fromVC
        guard (movingScreen as? HostedScreen)?.kind == .slide else {
            return nil
        }
        return SlideAnimator(isPresenting: operation == .push)
    }

    public func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController, animated: Bool) {
        setNavigationBarHidden(viewController === viewControllers.first, animated: animated)

        // A cancelled swipe back onto the root leaves the bar hidden under the screen that stays.
        viewController.transitionCoordinator?.notifyWhenInteractionChanges { [weak self] context in
            guard context.isCancelled, let self, let topViewController else { return }
            setNavigationBarHidden(topViewController === viewControllers.first, animated: true)
        }
    }

    public func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
        interactivePopGestureRecognizer?.isEnabled = (viewController as? HostedScreen)?.kind == .system && viewControllers.count > 1

        let current = viewControllers
        let popped = shownControllers.filter { current.contains($0) == false }
        shownControllers = current

        for case let screen as HostedScreen in popped {
            let onPop = screen.onPop
            screen.onPop = nil
            onPop?()
        }
    }
}

/// One screen of the stack; its bar look follows the kind it was pushed with.
private final class HostedScreen: UIHostingController<AnyView> {

    let kind: FlowPushKind
    var onPop: (@MainActor () -> Void)?

    var trailingItem: FlowBarItem? {
        didSet {
            guard let trailingItem else {
                navigationItem.rightBarButtonItem = nil
                return
            }
            let action = trailingItem.action
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                image: UIImage(systemName: trailingItem.systemImage),
                primaryAction: UIAction { _ in
                    action()
                }
            )
        }
    }

    init(kind: FlowPushKind) {
        self.kind = kind
        super.init(rootView: AnyView(EmptyView()))

        if kind == .slide {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithTransparentBackground()
            navigationItem.standardAppearance = appearance
            navigationItem.scrollEdgeAppearance = appearance
            navigationItem.compactAppearance = appearance
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private final class SlideAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    let isPresenting: Bool
    let duration: TimeInterval = Constants.slideDuration

    init(isPresenting: Bool) {
        self.isPresenting = isPresenting
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromView = transitionContext.view(forKey: .from),
              let toView = transitionContext.view(forKey: .to) else {
            transitionContext.completeTransition(false)
            return
        }

        let containerView = transitionContext.containerView
        let screenWidth = containerView.bounds.width

        if isPresenting {
            toView.transform = CGAffineTransform(translationX: screenWidth, y: 0)
            containerView.addSubview(toView)
        } else {
            toView.transform = CGAffineTransform(translationX: -screenWidth, y: 0)
            containerView.insertSubview(toView, belowSubview: fromView)
        }

        let animator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1.0) {
            if self.isPresenting {
                fromView.transform = CGAffineTransform(translationX: -screenWidth, y: 0)
                toView.transform = .identity
            } else {
                fromView.transform = CGAffineTransform(translationX: screenWidth, y: 0)
                toView.transform = .identity
            }
        }
        animator.addCompletion { _ in
            fromView.transform = .identity
            toView.transform = .identity

            transitionContext.completeTransition(true)
        }
        animator.startAnimation()
    }
}
