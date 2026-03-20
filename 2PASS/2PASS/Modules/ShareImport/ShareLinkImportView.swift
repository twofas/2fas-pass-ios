// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import CommonUI

struct ShareLinkImportView: View {

    @State var presenter: ShareLinkImportPresenter

    var body: some View {
        Group {
            switch presenter.state {
            case .editor(let changeRequest):
                ShareLinkImportEditorRepresentable(
                    changeRequest: changeRequest,
                    onClose: presenter.onEditorClosed
                )
                .ignoresSafeArea()
                .transition(.opacity)

            case .password:
                ShareLinkImportPasswordView(presenter: presenter)
                    .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .bottom)))

            case .loading:
                NavigationStack {
                    ProgressView()
                        .controlSize(.large)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                ToolbarCancelButton {
                                    presenter.onEditorClosed(.failure(.userCancelled))
                                }
                            }
                        }
                }
                .transition(.asymmetric(insertion: .opacity, removal: .identity))

            case .error:
                ResultView(kind: .failure, title: Text(.shareLinkImportErrorTitle)) {
                    Button(.commonClose) {
                        presenter.onEditorClosed(.failure(.userCancelled))
                    }
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: presenter.stateID)
        .onAppear {
            presenter.onAppear()
        }
        .onDisappear {
            presenter.onDisappear()
        }
    }
}

struct ShareLinkImportEditorRepresentable: UIViewControllerRepresentable {

    let changeRequest: any ItemDataChangeRequest
    let onClose: (SaveItemResult) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onClose: onClose)
    }

    func makeUIViewController(context: Context) -> UIViewController {
        ItemEditorNavigationFlowController.buildView(
            parent: context.coordinator,
            editItemID: nil,
            changeRequest: changeRequest
        )
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    final class Coordinator: ItemEditorNavigationFlowControllerParent {
        private let onClose: (SaveItemResult) -> Void

        init(onClose: @escaping (SaveItemResult) -> Void) {
            self.onClose = onClose
        }

        public func closeItemEditor(with result: SaveItemResult) {
            onClose(result)
        }
    }
}
