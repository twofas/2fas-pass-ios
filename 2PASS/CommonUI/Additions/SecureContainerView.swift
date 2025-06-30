// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public struct SecureContainerView<ID: Hashable, Content: View>: View {
    
    let contentId: ID
    @ViewBuilder var content: (ID) -> Content
    
    public var body: some View {
        _SecureContainerView(contentId: contentId, content: content)
    }
}

extension SecureContainerView {
    
    init(contentId: ID, @ViewBuilder content: @escaping () -> Content) {
        self.contentId = contentId
        self.content = { _ in content() }
    }
}

extension SecureContainerView where ID == UUID {
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.contentId = UUID()
        self.content = { _ in content() }
    }
}

private struct _SecureContainerView<ID: Hashable, Content: View>: UIViewRepresentable {
    
    let contentId: ID
    @ViewBuilder var content: (ID) -> Content
    
    func makeUIView(context: Context) -> UIView {
        let secureEntryTextField = UITextField()
        secureEntryTextField.isSecureTextEntry = true
        secureEntryTextField.isUserInteractionEnabled = false
        
        guard let container = secureEntryTextField.layer.sublayers?.first?.delegate as? UIView else {
            return UIView()
        }
        
        clearContainer(container)
        context.coordinator.hosting = embedContent(in: container)
        
        return container
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.hosting?.rootView = content(contentId)
    }
    
    private func clearContainer(_ container: UIView) {
        container.subviews.forEach { subview in
            subview.removeFromSuperview()
        }
    }
    
    private func embedContent(in container: UIView) -> UIHostingController<Content> {
        let contentHostingController = UIHostingController(rootView: content(contentId))
        contentHostingController.view.backgroundColor = .clear
        
        container.addSubview(contentHostingController.view)
        contentHostingController.view.pinToParent()
        
        return contentHostingController
    }
    
    func makeCoordinator() -> Coordinator {
        .init()
    }
    
    class Coordinator {
        fileprivate var hosting: UIHostingController<Content>?
    }
}
