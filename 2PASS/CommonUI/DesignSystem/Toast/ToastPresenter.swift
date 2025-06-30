// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

extension View {
    
    @ViewBuilder
    public func toast(_ text: Text, isPresented: Binding<Bool>, style: ToastStyle, icon: Image? = nil, sensoryFeedback: @escaping SensoryFeedbackConfiguration = { $0 }) -> some View {
        modifier(ToastPresenterViewModifier(text: text, isPresented: isPresented, style: style, icon: icon, sensoryFeedback: sensoryFeedback))
    }
}

final public class ToastPresenter {

    public static let shared = ToastPresenter()
    
    private let window = UIWindow()

    private var preseted: [UUID: ToastPresentationController] = [:]
    
    @discardableResult
    public func present(_ text: Text, style: ToastStyle, icon: Image? = nil, sensoryFeedback: @escaping SensoryFeedbackConfiguration = { $0 }, onDismiss: @escaping Callback = {}) -> UUID {
        let id = UUID()
        let controller = ToastPresentationController(id: id, onDismiss: {
            self.preseted[id] = nil
            
            if self.preseted.isEmpty {
                self.window.rootViewController = nil
                self.window.isHidden = true
            }
            
            onDismiss()
        })
        preseted[id] = controller

        let toastView = ToastPresenterView(
            toast: ToastContentView(text: text, style: style, icon: icon),
            controller: controller
        )
        .sensoryFeedbackConfiguration(sensoryFeedback)
        
        let toastViewController = UIHostingController(rootView: toastView)
        toastViewController.view.backgroundColor = .clear
        
        let toastSize = toastViewController.sizeThatFits(in: UIScreen.main.bounds.size)
        window.frame = CGRect(x: 0, y: 0, width: toastSize.width, height: toastSize.height)
        window.center.x = UIScreen.main.bounds.width / 2.0
        window.windowLevel = .alert
        
        window.rootViewController = toastViewController
        window.isHidden = false
        window.backgroundColor = .clear
        
        return id
    }
    
    public func dismiss(id: UUID) {
        guard let controller = preseted[id] else { return }
        controller.hide()
    }
    
    public func dismissAll(animated: Bool) {
        if animated {
            for controller in preseted.values {
                controller.hide()
            }
        } else {
            self.preseted = [:]
            self.window.rootViewController = nil
            self.window.isHidden = true
        }
    }
}

extension ToastPresenter {
    
    public func present(_ text: String, style: ToastStyle, icon: UIImage? = nil, sensoryFeedback: @escaping SensoryFeedbackConfiguration = { $0 }, onDismiss: @escaping Callback = {}) {
        self.present(Text(text), style: style, icon: icon.map(Image.init), sensoryFeedback: sensoryFeedback, onDismiss: onDismiss)
    }
}

private struct ToastPresenterViewModifier: ViewModifier {
    
    let text: Text
    let isPresented: Binding<Bool>
    let style: ToastStyle
    let icon: Image?
    let sensoryFeedback: SensoryFeedbackConfiguration
    
    @State private var toastId: UUID?
    
    @Environment(\.toastPresenenter)
    private var toastPresenter
    
    func body(content: Content) -> some View {
        content
            .onChange(of: isPresented.wrappedValue) { oldValue, newValue in
                if newValue {
                    toastId = toastPresenter.present(text, style: style, icon: icon, sensoryFeedback: sensoryFeedback, onDismiss: {
                        isPresented.wrappedValue = false
                    })
                } else if let toastId {
                    toastPresenter.dismiss(id: toastId)
                }
            }
    }
}

extension EnvironmentValues {
    
    public var toastPresenenter: ToastPresenter {
        get {
            self[ToastPresenterEnvironemntKey.self]
        } set {
            self[ToastPresenterEnvironemntKey.self] = newValue
        }
    }
}

private struct ToastPresenterEnvironemntKey: EnvironmentKey {
    static let defaultValue: ToastPresenter = .shared
}
