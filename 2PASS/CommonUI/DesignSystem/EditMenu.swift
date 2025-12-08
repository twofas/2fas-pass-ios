// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import SwiftUI

extension View {
    
    public func editMenu(_ binding: Binding<Bool>, actions: [UIAction]) -> some View {
        background(
            EditMenuController(actions: actions, binding: Binding(get: {
                binding.wrappedValue
            }, set: {
                binding.wrappedValue = $0 ?? false
            }), value: true)
        )
    }
    
    public func editMenu<Value>(_ binding: Binding<Value?>, equals value: Value, actions: [UIAction]) -> some View where Value: Hashable {
        background(
            EditMenuController(actions: actions, binding: binding, value: value)
        )
    }
}

struct EditMenuController<Value>: UIViewRepresentable where Value: Hashable {
    
    let actions: [UIAction]
    @Binding var binding: Value?
    let value: Value
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let interaction = UIEditMenuInteraction(delegate: context.coordinator)
        view.addInteraction(interaction)
        context.coordinator.interaction = interaction
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if binding == value {
            Task { @MainActor in
                context.coordinator.showMenu(in: uiView.bounds, actions: actions, binding: _binding)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, UIEditMenuInteractionDelegate {
        
        fileprivate var interaction: UIEditMenuInteraction?
        
        private var binding: Binding<Value?>?
        private var sourceRect: CGRect = .zero
        private var actions: [UIAction] = []
        
        func showMenu(in rect: CGRect, actions: [UIAction], binding: Binding<Value?>?) {
            guard let interaction else { return }
            
            sourceRect = rect
            self.actions = actions
            self.binding = binding

            let config = UIEditMenuConfiguration(identifier: UUID(), sourcePoint: .zero)
            config.preferredArrowDirection = .down
            interaction.presentEditMenu(with: config)
        }
        
        func editMenuInteraction(_ interaction: UIEditMenuInteraction, menuFor configuration: UIEditMenuConfiguration, suggestedActions: [UIMenuElement]) -> UIMenu? {
            UIMenu(children: actions)
        }
        
        func editMenuInteraction(_ interaction: UIEditMenuInteraction, willDismissMenuFor configuration: UIEditMenuConfiguration, animator: any UIEditMenuInteractionAnimating) {
            binding?.wrappedValue = nil
        }
        
        func editMenuInteraction(_ interaction: UIEditMenuInteraction, targetRectFor configuration: UIEditMenuConfiguration) -> CGRect {
            sourceRect
        }
    }
}
