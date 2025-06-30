// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

private struct Constants {
    static let sourceSize = CGSize(width: 60, height: 10)
    static let autohideDelay = Duration.seconds(2)
    static let sensoryFeedbackDelay = Duration.milliseconds(100)
    
    static let topPadding: CGFloat = 32
    
    static let presentAnimationDuration = 0.5
    static let dismissAnimationDuration = 0.4
    static let opacityAnimationDuration = 0.2
}

public typealias SensoryFeedbackConfiguration = (SensoryFeedback?) -> SensoryFeedback?

@Observable
final class ToastPresentationController {
    
    let id: UUID
    
    var toastSize = CGSize.zero
    
    private(set) var isPresented: Bool = false
    private(set) var scale = CGSize(width: 1, height: 1)
    
    private let _onDismiss: Callback?
    
    init(id: UUID, onDismiss: @escaping Callback) {
        self.id = id
        self._onDismiss = onDismiss
    }
    
    func onAppear() {
        var transaciton = Transaction()
        transaciton.disablesAnimations = true
        withTransaction(transaciton) {
            scale = sourceScale
        }
    
        isPresented = true
        scale = CGSize(width: 1, height: 1)
        
        Task {
            try await Task.sleep(for: Constants.autohideDelay)
            hide()
        }
    }
    
    func hide() {
        withAnimation {
            isPresented = false
            scale = sourceScale
        } completion: {
            self._onDismiss?()
        }
    }
    
    private var sourceScale: CGSize {
        CGSize(
            width: min(1, Constants.sourceSize.width / toastSize.width),
            height: min(1, Constants.sourceSize.height / toastSize.height)
        )
    }
}


struct ToastPresenterView: View {
    
    let toast: ToastContentView
    
    @State
    var controller: ToastPresentationController
    
    init(toast: ToastContentView, controller: ToastPresentationController) {
        self.toast = toast
        self.controller = controller
        self.sensoryFeedbackConfiguration = { $0 }
    }
    
    @Environment(\.colorScheme)
    private var colorScheme
    
    @State
    private var sensoryFeedback: Bool = false
    
    private var sensoryFeedbackConfiguration: SensoryFeedbackConfiguration
    
    var body: some View {
        VStack {
            toast
                .background(
                    ZStack {
                        Capsule()
                            .fill(colorScheme == .dark ? .neutral100 : .baseStatic0)
                            .shadow(color: .black.opacity(0.15), radius: 25, x: 0, y: 20)
                            .shadow(color: Color(red: 0.15, green: 0.15, blue: 0.15).opacity(0.69), radius: 0, x: 0, y: 0)
                            .opacity(controller.isPresented ? 1 : 0)
                        
                        Capsule()
                            .fill(colorScheme == .dark ? .neutral100 : .baseStatic0)
                    }
                )
                .onGeometryChange(for: CGSize.self, of: { proxy in
                    proxy.size
                }, action: { newValue in
                    controller.toastSize = newValue
                })
                .padding(.top, Constants.topPadding)
                .scaleEffect(controller.scale)
                .offset(y: controller.isPresented ? 0 : -controller.toastSize.height)
                .animation(.smooth(duration: controller.isPresented ? Constants.presentAnimationDuration : Constants.dismissAnimationDuration), value: controller.scale)
                .animation(.smooth(duration: controller.isPresented ? Constants.presentAnimationDuration : Constants.dismissAnimationDuration), value: controller.isPresented)
                .opacity(controller.isPresented ? 1 : 0)
                .animation(.easeInOut(duration: Constants.opacityAnimationDuration), value: controller.isPresented)
        }
        .onChange(of: controller.isPresented, { oldValue, newValue in
            guard newValue else {
                return
            }
            Task {
                try await Task.sleep(for: Constants.sensoryFeedbackDelay)
                sensoryFeedback = true
            }
        })
        .sensoryFeedback(trigger: sensoryFeedback, { oldValue, newValue in
            let proposal: SensoryFeedback? = {
                switch toast.style {
                case .success: return .success
                case .failure: return .error
                case .warning: return .warning
                case .info: return .impact
                }
            }()
            return sensoryFeedbackConfiguration(proposal)
        })
        .onAppear {
            controller.onAppear()
        }
    }
    
    func sensoryFeedbackConfiguration(_ configuration: @escaping SensoryFeedbackConfiguration) -> Self {
        var instance = self
        instance.sensoryFeedbackConfiguration = configuration
        return instance
    }
}

#Preview {
    VStack {
        ToastPresenterView(
            toast: .init(text: Text("Example message"), style: .info),
            controller: ToastPresentationController(id: UUID(), onDismiss: {})
        )
        
        Spacer()
    }
}
