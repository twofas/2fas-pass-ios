// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct BackupConfigEditorCancelItem: ToolbarContent {

    private let hasUnsavedChanges: Bool
    @Binding private var isConfirmationPresented: Bool
    private let onDismiss: () -> Void

    init(
        hasUnsavedChanges: Bool,
        isConfirmationPresented: Binding<Bool>,
        onDismiss: @escaping () -> Void
    ) {
        self.hasUnsavedChanges = hasUnsavedChanges
        self._isConfirmationPresented = isConfirmationPresented
        self.onDismiss = onDismiss
    }

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            ToolbarCancelButton {
                if hasUnsavedChanges {
                    isConfirmationPresented = true
                } else {
                    onDismiss()
                }
            }
            .confirmationDialog(
                Text(.backupConfigsUnsavedChangesDialogTitle),
                isPresented: $isConfirmationPresented,
                titleVisibility: .hidden
            ) {
                Button(role: .destructive, action: onDismiss) {
                    Text(.commonDiscardChanges)
                }
            } message: {
                Text(.backupConfigsUnsavedChangesDialogDescription)
            }
        }
    }
}
