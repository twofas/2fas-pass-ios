// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import UIKit

private struct Constants {
    static let keyboardHideWait: Duration = .milliseconds(500)
}

/// One system-owned navigation stack whose screens are SwiftUI views; a `.slide` push keeps the
/// onboarding's slide transition and a transparent bar, a `.system` push is the plain UIKit one.
@MainActor
public final class SlideNavigationController: UINavigationController {

    /// The slide's length, for an overlay that wants to enter and leave with a `.slide` screen.
    public static let slideDuration: TimeInterval = 0.5

    private let decorate: (AnyView) -> AnyView
    private let keyboardObserver = KeyboardObserver()
    private var overlayController: UIViewController?
    private let overlayInsets = OverlayInsets()

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
        overlayController?.view.removeFromSuperview()

        // Only the view joins the hierarchy: `addChild` on a navigation controller pushes the child.
        let controller = UIHostingController(rootView: OverlayRoot(insets: overlayInsets, overlay: overlay))
        controller.view.backgroundColor = .clear
        controller.view.isUserInteractionEnabled = false
        view.addSubview(controller.view)
        controller.view.pinToParent()
        overlayController = controller
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        // A navigation delegate that answers `animationControllerFor` silences UIKit's own gesture
        // delegate, so the swipe back is judged here: on a `.system` screen alone (D2).
        interactivePopGestureRecognizer?.delegate = self
    }

    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if let overlayView = overlayController?.view {
            view.bringSubviewToFront(overlayView)
        }

        // The overlay's safe area follows the shown screen's, so it clears the bar where there is one
        // and nothing where the system moved the items elsewhere.
        let barInset = max(0, (topViewController?.view.safeAreaInsets.top ?? 0) - view.safeAreaInsets.top)
        if overlayInsets.top != barInset {
            overlayInsets.top = barInset
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
                .onPreferenceChange(FlowOverlayClaimPreferenceKey.self) { [weak screen] claims in
                    screen?.claimsOverlay = claims
                }
        )
        return screen
    }

    private func push(_ view: AnyView, kind: FlowPushKind, onPop: @escaping @MainActor () -> Void) {
        let screen = host(view, kind: kind)
        screen.onPop = onPop

        afterHidingKeyboard(forSlide: kind == .slide) { [weak self] in
            guard let self else { return }

            // The back button a screen shows belongs to the item below it, so it is set before the push.
            topViewController?.navigationItem.backButtonDisplayMode = kind == .slide ? .minimal : .default
            pushViewController(screen, animated: true)
        }
    }

    private func pop(to screen: UIViewController) {
        let leavingSlide = (viewControllers.last as? HostedScreen)?.kind == .slide
        afterHidingKeyboard(forSlide: leavingSlide) { [weak self] in
            guard let self, viewControllers.contains(screen), topViewController !== screen else { return }
            popToViewController(screen, animated: true)
        }
    }

    // The slide moves the whole screen, keyboard included, so it waits for the keyboard to leave first;
    // the system transition handles the keyboard itself.
    private func afterHidingKeyboard(forSlide isSlide: Bool, _ navigate: @escaping @MainActor () -> Void) {
        guard isSlide, keyboardObserver.isKeyboardVisible else {
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

        // The overlay rides with the moving screen when the screen that stays shows nothing in it,
        // so what the overlay holds enters and leaves as a part of the screen that claims it.
        let stayingScreen = operation == .push ? fromVC : toVC
        let overlayRides = (stayingScreen as? HostedScreen)?.claimsOverlay != true
        return SlideAnimator(isPresenting: operation == .push, overlay: overlayRides ? overlayController?.view : nil)
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

@MainActor @Observable
private final class OverlayInsets {
    var top: CGFloat = 0
}

/// Pads the overlay's safe area by the bar's height, so it lays out as the screen under it does.
private struct OverlayRoot<Overlay: View>: View {
    let insets: OverlayInsets
    let overlay: Overlay

    var body: some View {
        overlay
            .safeAreaPadding(.top, insets.top)
    }
}

extension SlideNavigationController: UIGestureRecognizerDelegate {

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer === interactivePopGestureRecognizer else { return true }

        return viewControllers.count > 1
            && (viewControllers.last as? HostedScreen)?.kind == .system
            && transitionCoordinator == nil
    }
}

/// One screen of the stack; its bar look follows the kind it was pushed with.
private final class HostedScreen: UIHostingController<AnyView> {

    let kind: FlowPushKind
    var onPop: (@MainActor () -> Void)?
    var claimsOverlay = false

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
    let duration: TimeInterval = SlideNavigationController.slideDuration

    // The stack's overlay view when it moves with the screen; a snapshot stands in for it on the
    // way out, since the content it shows may leave before the slide ends.
    private let overlay: UIView?

    init(isPresenting: Bool, overlay: UIView?) {
        self.isPresenting = isPresenting
        self.overlay = overlay
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
        let ridingOverlay = ridingOverlayView(screenWidth: screenWidth)

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
                ridingOverlay?.transform = .identity
            } else {
                fromView.transform = CGAffineTransform(translationX: screenWidth, y: 0)
                toView.transform = .identity
                ridingOverlay?.transform = CGAffineTransform(translationX: screenWidth, y: 0)
            }
        }
        animator.addCompletion { _ in
            fromView.transform = .identity
            toView.transform = .identity
            self.endRide(of: ridingOverlay)

            transitionContext.completeTransition(true)
        }
        animator.startAnimation()
    }

    // Entering: the overlay itself starts off screen and comes in with the screen. Leaving: a
    // snapshot of it goes out with the screen while the overlay is hidden.
    private func ridingOverlayView(screenWidth: CGFloat) -> UIView? {
        guard let overlay else { return nil }

        if isPresenting {
            overlay.transform = CGAffineTransform(translationX: screenWidth, y: 0)
            return overlay
        }
        guard let snapshot = overlay.snapshotView(afterScreenUpdates: false) else { return nil }
        snapshot.frame = overlay.frame
        overlay.superview?.insertSubview(snapshot, aboveSubview: overlay)
        overlay.isHidden = true
        return snapshot
    }

    private func endRide(of ridingOverlay: UIView?) {
        guard let overlay, let ridingOverlay else { return }

        if ridingOverlay === overlay {
            overlay.transform = .identity
        } else {
            ridingOverlay.removeFromSuperview()
            overlay.isHidden = false
        }
    }
}
