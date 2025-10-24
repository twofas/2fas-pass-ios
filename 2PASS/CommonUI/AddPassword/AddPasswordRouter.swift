// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import SwiftUI

public struct AddPasswordRouter {

    public static func buildView(id: ItemID?, changeRequest: PasswordDataChangeRequest?, onClose: @escaping (SavePasswordResult) -> Void) -> some View {
        AddPasswordView_UIKit(editItemID: id, changeRequest: changeRequest, onClose: onClose)
            .ignoresSafeArea()
    }
}

private struct AddPasswordView_UIKit: UIViewControllerRepresentable {
    
    let editItemID: ItemID?
    let changeRequest: PasswordDataChangeRequest?
    let onClose: (SavePasswordResult) -> Void
    
    func makeUIViewController(context: Context) -> UIViewController {
        AddPasswordNavigationFlowController.buildView(parent: context.coordinator, editItemID: editItemID, changeRequest: changeRequest)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        .init(parent: self)
    }
    
    class Coordinator: AddPasswordNavigationFlowControllerParent {
        
        let parent: AddPasswordView_UIKit
        
        init(parent: AddPasswordView_UIKit) {
            self.parent = parent
        }
        
        func closeAddPassword(with result: SavePasswordResult) {
            parent.onClose(result)
        }
    }
}
