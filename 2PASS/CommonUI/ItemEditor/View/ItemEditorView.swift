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
            }
            
            if presenter.showRemoveItemButton {
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Text(T.loginDeleteCta.localizedKey)
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
        .alert(T.loginErrorSave.localizedKey, isPresented: $presenter.cantSave) {
            Button(T.commonOk.localizedKey, role: .cancel) {
                presenter.cantSave = false
            }
        }
        .alert(T.loginErrorEditedOtherDevice.localizedKey, isPresented: $presenter.passwordWasEdited) {
            Button(T.commonClose.localizedKey, role: .cancel) {
                presenter.onClose()
            }
        }
        .alert(T.loginErrorDeletedOtherDevice.localizedKey, isPresented: $presenter.passwordWasDeleted) {
            Button(T.commonClose.localizedKey, role: .cancel) {
                presenter.onClose()
            }
        }
        .alert(T.loginDeleteConfirmTitle.localizedKey, isPresented: $showDeleteConfirmation, actions: {
            Button(role: .destructive) {
                presenter.onDelete()
            } label: {
                Text(T.commonYes.localizedKey)
            }

            Button(role: .cancel) {} label: {
                Text(T.commonNo.localizedKey)
            }
        }, message: {
            Text(T.loginDeleteConfirmBody.localizedKey)
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
