// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Common
import SwiftUI

public struct ItemEditorRouter {

    public static func buildView(id: ItemID?, changeRequest: LoginDataChangeRequest?, onClose: @escaping (SaveItemResult) -> Void) -> some View {
        ItemEditorView_UIKit(editItemID: id, changeRequest: changeRequest, onClose: onClose)
            .ignoresSafeArea()
    }
}

private struct ItemEditorView_UIKit: UIViewControllerRepresentable {

    let editItemID: ItemID?
    let changeRequest: LoginDataChangeRequest?
    let onClose: (SaveItemResult) -> Void

    func makeUIViewController(context: Context) -> UIViewController {
        ItemEditorNavigationFlowController.buildView(parent: context.coordinator, editItemID: editItemID, changeRequest: changeRequest)
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
    }

    func makeCoordinator() -> Coordinator {
        .init(parent: self)
    }

    class Coordinator: ItemEditorNavigationFlowControllerParent {

        let parent: ItemEditorView_UIKit

        init(parent: ItemEditorView_UIKit) {
            self.parent = parent
        }

        func closeItemEditor(with result: SaveItemResult) {
            parent.onClose(result)
        }
    }
}
