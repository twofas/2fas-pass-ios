// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

extension View {
    
    public func slideNavigationDestination<V>(isPresented: Binding<Bool>, @ViewBuilder destination: @escaping () -> V) -> some View where V : View {
        modifier(SlideNavigationDestinationModifier(isPresented: isPresented, destination: {
            AnyView(
                destination()
                    .slideToolbarTrailingItems({})
            )
        }))
    }
    
    public func slideToolbarTrailingItems<Items>(@ViewBuilder _ items: () -> Items) -> some View where Items: View {
        modifier(SlideNavigationToolbarItemsModifier(items: AnyView(items())))
    }
}

extension View {
    
    @ViewBuilder
    public func slideNavigationButtonLabel() -> some View {
        if #available(iOS 26, *) {
            font(.system(size: 22, weight: .light))
                .frame(width: 30, height: 30)
        } else {
            font(.system(size: 22))
        }
    }
        
}

public struct SlideNavigationStack<RootView: View>: View {
    private var root: RootView

    @State private var path: [SlideNavigationDestinationItem] = []
    @Environment(\.dismiss) var dismiss

    @State private var keyboardObserver = KeyboardObserver()
    @State private var toolbarItem: SlideNavigationToolbarItem?
    
    public init(@ViewBuilder root: () -> RootView) {
        self.root = root()
    }
    
    public var body: some View {
        SlideNavigationController_UIKit(path: path, root: root)
            .overlay(alignment: .top) {
                HStack {
                    if #available(iOS 26, *) {
                        Button {
                            toolbarItem = nil
                            back()
                        } label: {
                            Image(systemName: "chevron.backward")
                                .slideNavigationButtonLabel()
                        }
                        .tint(nil)
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                    } else {
                        Button {
                            toolbarItem = nil
                            back()
                        } label: {
                            Label(title: { Text(T.commonBack.localizedKey) }, icon: { Image(systemName: "chevron.backward").font(.title2) })
                                .labelStyle(ButtonLabelStyle())
                        }
                    }
                    
                    Spacer()
                    
                    if #available(iOS 26, *) {
                        toolbarItem?.view
                            .tint(nil)
                            .buttonStyle(.glass)
                            .buttonBorderShape(.circle)
                    } else {
                        toolbarItem?.view
                    }
                }
                .animation(.easeInOut, value: toolbarItem != nil)
                .padding(.horizontal, Spacing.s)
                .frame(height: 44)
            }
            .onPreferenceChange(SlideNavigationDestinationPreferenceKey.self) { value in
                if keyboardObserver.isKeyboardVisible {
                    hideKeyboard()
                    
                    Task { @MainActor in
                        try await Task.sleep(for: .milliseconds(500))
                        path = value
                    }
                    
                } else {
                    path = value
                }
            }
            .onPreferenceChange(SlideNavigationToolbarTrailingItemsPreferenceKey.self) { value in
                toolbarItem = value
            }
    }
    
    private func back() {
        func pefromPopOrDismiss() {
            if path.count > 0 {
                path.last?.isPresented.wrappedValue = false
            } else {
                dismiss()
            }
        }
        
        if keyboardObserver.isKeyboardVisible {
            hideKeyboard()
            
            Task {
                try await Task.sleep(for: .milliseconds(500))
                pefromPopOrDismiss()
            }
        } else {
            pefromPopOrDismiss()
        }
    }
    
    private func hideKeyboard() {
        let connectedScenes = UIApplication.shared.connectedScenes
        let windowScene = connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        windowScene?.keyWindow?.endEditing(true)
    }
}

private struct SlideNavigationDestinationModifier: ViewModifier {
    
    let isPresented: Binding<Bool>
    let destination: () -> AnyView
    @Namespace private var id
    
    func body(content: Content) -> some View {
        content
            .background(
                Color.clear
                    .preference(
                        key: SlideNavigationDestinationPreferenceKey.self,
                        value: isPresented.wrappedValue ? [SlideNavigationDestinationItem(
                            id: id,
                            isPresented: isPresented,
                            destination: isPresented.wrappedValue ? destination() : nil
                        )] : []
                    )
            )
    }
}

private struct SlideNavigationDestinationItem: Equatable {
    let id: Namespace.ID
    var isPresented: Binding<Bool>
    let destination: AnyView?
    
    static func ==(lhs: SlideNavigationDestinationItem, rhs: SlideNavigationDestinationItem) -> Bool {
        lhs.id == rhs.id && lhs.isPresented.wrappedValue == rhs.isPresented.wrappedValue
    }
}

private struct SlideNavigationDestinationPreferenceKey: PreferenceKey {
    static var defaultValue: [SlideNavigationDestinationItem] {
        []
    }
    
    static func reduce(value: inout [SlideNavigationDestinationItem], nextValue: () -> [SlideNavigationDestinationItem]) {
        value.append(contentsOf: nextValue())
    }
}

private struct SlideNavigationToolbarItem: Equatable {
    let id: Namespace.ID
    let view: AnyView
    
    static func ==(lhs: SlideNavigationToolbarItem, rhs: SlideNavigationToolbarItem) -> Bool {
        lhs.id == rhs.id
    }
}

private struct SlideNavigationToolbarItemsModifier: ViewModifier {
    let items: AnyView
    @Namespace private var id
    
    func body(content: Content) -> some View {
        content
            .background(
                Color.clear
                    .preference(key: SlideNavigationToolbarTrailingItemsPreferenceKey.self, value: SlideNavigationToolbarItem(id: id, view: items))
            )
    }
}

private struct SlideNavigationToolbarTrailingItemsPreferenceKey: PreferenceKey {
    static var defaultValue: SlideNavigationToolbarItem? {
        nil
    }
    
    static func reduce(value: inout SlideNavigationToolbarItem?, nextValue: () -> SlideNavigationToolbarItem?) {
        value = nextValue() ?? value
    }
}

private struct SlideNavigationController_UIKit<V>: UIViewControllerRepresentable where V: View {
    
    let path: [SlideNavigationDestinationItem]
    let root: V
    
    func makeUIViewController(context: Context) -> UINavigationController {
        let v = UINavigationController(rootViewController: UIHostingController(rootView: root))
        v.delegate = context.coordinator
        v.setNavigationBarHidden(true, animated: false)
        return v
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        let isPush = path.count > uiViewController.viewControllers.count - 1
        let isPop = path.count < uiViewController.viewControllers.count - 1
        
        if isPush, let view = path.last {
            let vc = UIHostingController(rootView: view.destination!)
            uiViewController.pushViewController(vc, animated: true)
        } else if isPop {
            uiViewController.popViewController(animated: true)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, UINavigationControllerDelegate {
        
        func navigationController(_ navigationController: UINavigationController, animationControllerFor operation: UINavigationController.Operation, from fromVC: UIViewController, to toVC: UIViewController) -> (any UIViewControllerAnimatedTransitioning)? {
            SlideAnimator(isPresenting: operation == .push)
        }
    }
}

private class SlideAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    let isPresenting: Bool
    let duration: TimeInterval = 0.5

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
