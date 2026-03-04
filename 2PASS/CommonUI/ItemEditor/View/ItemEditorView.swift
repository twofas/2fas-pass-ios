// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct ItemEditorFormView: View {
    
    @State
    var presenter: ItemEditorPresenter
    var resignFirstResponder: () -> Void

    @State
    private var showDeleteConfirmation = false
    
    @Namespace var namespace
    
    var body: some View {
        Form {
            switch presenter.form {
            case .login(let presenter):
                LoginEditorFormView(
                    presenter: presenter,
                    resignFirstResponder: resignFirstResponder
                )
            case .secureNote(let presenter):
                SecureNoteEditorFormView(
                    presenter: presenter,
                    resignFirstResponder: resignFirstResponder
                )
            case .paymentCard(let presenter):
                PaymentCardEditorFormView(
                    presenter: presenter,
                    resignFirstResponder: resignFirstResponder
                )
            case .wifi(let presenter):
                WiFiEditorFormView(
                    presenter: presenter,
                    resignFirstResponder: resignFirstResponder
                )
            }
            
            if presenter.showRemoveItemButton {
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Text(.loginDeleteCta)
                    }
                }
                .id(presenter.contentType)
            }
        }
        .environment(\.editMode, .constant(EditMode.active))
        .contentMargins(.top, Spacing.s)
        .formStyle(.grouped)
        .onAppear {
            presenter.onAppear()
        }
        .onDisappear {
            presenter.onDisappear()
        }
        .alert(String(localized: .loginErrorSave), isPresented: $presenter.cantSave) {
            Button(.commonOk, role: .cancel) {
                presenter.cantSave = false
            }
        }
        .alert(String(localized: .loginErrorEditedOtherDevice), isPresented: $presenter.passwordWasEdited) {
            Button(.commonClose, role: .cancel) {
                presenter.onClose()
            }
        }
        .alert(String(localized: .loginErrorDeletedOtherDevice), isPresented: $presenter.passwordWasDeleted) {
            Button(.commonClose, role: .cancel) {
                presenter.onClose()
            }
        }
        .alert(String(localized: .loginDeleteConfirmTitle), isPresented: $showDeleteConfirmation, actions: {
            Button(role: .destructive) {
                presenter.onDelete()
            } label: {
                Text(.commonYes)
            }

            Button(role: .cancel) {} label: {
                Text(.commonNo)
            }
        }, message: {
            Text(.loginDeleteConfirmBody)
        })
    }
}

#Preview {
    ItemEditorFormView(
        presenter: ItemEditorPresenter(
            flowController: ItemEditorFlowController(viewController: UIViewController()),
            interactor: ModuleInteractorFactory.shared.itemEditorInteractor(editItemID: nil)
        ),
        resignFirstResponder: {}
    )
}
