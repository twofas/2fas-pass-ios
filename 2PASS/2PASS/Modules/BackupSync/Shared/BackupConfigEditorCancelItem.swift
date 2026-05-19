// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

/// Cancellation-action toolbar item for backup config forms with an unsaved-changes
/// confirmation dialog anchored to the cancel button.
///
/// - Cancel tap with unsaved changes → opens the discard confirmation dialog.
/// - Cancel tap with no unsaved changes → invokes `onDismiss` directly.
/// - Discard confirm in dialog → invokes `onDismiss`.
///
/// `isConfirmationPresented` is exposed as a `Binding` so the surrounding screen can
/// programmatically open the same dialog (e.g. from a swipe-dismiss catcher) and the
/// iPad popover stays anchored to the toolbar cancel button.
///
/// ```
/// BackupConfigEditorCancelItem(
///     hasUnsavedChanges: presenter.hasUnsavedChanges,
///     isConfirmationPresented: $isDiscardConfirmationPresented
/// ) {
///     hideKeyboard()
///     dismiss()
/// }
/// ```
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
