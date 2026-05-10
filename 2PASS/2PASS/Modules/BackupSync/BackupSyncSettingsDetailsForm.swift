// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Backup

/// Reusable wrapper for backup config forms (S3, WebDAV) that bundles:
/// - The `SettingsDetailsForm` shell + content with interactive keyboard dismissal
/// - The principal toolbar title, an edit-mode cancel item with discard guard, and a save item
/// - The drag-dismiss attempt catcher for swipe-dismiss with unsaved changes
/// - The centered "Unsaved changes" alert used as the add-mode fallback (no anchor available)
///
/// `onClose` is invoked for every "user is leaving" path: edit-mode cancel-tap with no
/// unsaved changes, edit-mode discard-confirm, and add-mode swipe-then-discard. The
/// consumer routes through `presenter.close()` so the close request reaches the host
/// presentation's dismiss — works in both sheet-root (edit) and pushed-into-stack (add)
/// hosting contexts via the presenter's `onClose` wiring.
///
/// ```
/// BackupSyncSettingsDetailsForm(
///     kind: .s3,
///     title: .backupConfigsRowS3Title,
///     onSave: { … },
///     onClose: { … }
/// ) {
///     Section { … }
/// }
/// .editMode(presenter.isEditMode)
/// .unsavedChanges(presenter.hasUnsavedChanges)
/// .saving(presenter.isTesting)
/// .canSave(presenter.canSave)
/// ```
struct BackupSyncSettingsDetailsForm<Content: View>: View {

    private let kind: SyncServiceKind
    private let title: Text
    private let onSave: () -> Void
    private let onClose: () -> Void
    private let content: () -> Content

    private var isEditMode = false
    private var hasUnsavedChanges = false
    private var isSaving = false
    private var canSave = true

    @State private var isDiscardConfirmationPresented = false
    @State private var isAddModeDiscardAlertPresented = false

    init(
        kind: SyncServiceKind,
        title: Text,
        onSave: @escaping () -> Void,
        onClose: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.kind = kind
        self.title = title
        self.onSave = onSave
        self.onClose = onClose
        self.content = content
    }

    var body: some View {
        SettingsDetailsForm(title) {
            content()
        }
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            BackupConfigToolbarTitle(kind: kind, title: title)
            if isEditMode {
                BackupConfigCancelItem(
                    hasUnsavedChanges: hasUnsavedChanges,
                    isConfirmationPresented: $isDiscardConfirmationPresented,
                    onDismiss: onClose
                )
            }
            ToolbarSaveItem(action: onSave)
                .loading(isSaving)
                .disabled(!canSave)
        }
        .background(
            DragDismissAttemptCatcher(isEnabled: hasUnsavedChanges) {
                if isEditMode {
                    isDiscardConfirmationPresented = true
                } else {
                    isAddModeDiscardAlertPresented = true
                }
            }
        )
        .backupConfigUnsavedChangesAlert(
            isPresented: $isAddModeDiscardAlertPresented,
            onDiscard: onClose
        )
    }

    func editMode(_ enabled: Bool = true) -> Self {
        var instance = self
        instance.isEditMode = enabled
        return instance
    }

    func unsavedChanges(_ flag: Bool = true) -> Self {
        var instance = self
        instance.hasUnsavedChanges = flag
        return instance
    }

    func saving(_ flag: Bool = true) -> Self {
        var instance = self
        instance.isSaving = flag
        return instance
    }

    func canSave(_ flag: Bool) -> Self {
        var instance = self
        instance.canSave = flag
        return instance
    }
}

extension BackupSyncSettingsDetailsForm {

    init(
        kind: SyncServiceKind,
        title: LocalizedStringResource,
        onSave: @escaping () -> Void,
        onClose: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            kind: kind,
            title: Text(title),
            onSave: onSave,
            onClose: onClose,
            content: content
        )
    }
}
