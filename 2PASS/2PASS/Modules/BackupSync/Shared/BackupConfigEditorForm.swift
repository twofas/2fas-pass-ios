// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Backup

struct BackupConfigEditorForm<Content: View>: View {

    private let kind: BackupSyncService
    private let title: Text
    private let onSave: () -> Void
    private let onClose: () -> Void
    private let content: () -> Content

    private let hasUnsavedChanges: Bool
    private let isSaving: Bool
    private let canSave: Bool

    private var isEditMode = false
    private var confirmLabel: Text?
    private var isCancellable = false

    @State private var isDiscardConfirmationPresented = false
    @State private var isAddModeDiscardAlertPresented = false

    init(
        kind: BackupSyncService,
        title: Text,
        hasUnsavedChanges: Bool,
        isSaving: Bool,
        canSave: Bool,
        onSave: @escaping () -> Void,
        onClose: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.kind = kind
        self.title = title
        self.hasUnsavedChanges = hasUnsavedChanges
        self.isSaving = isSaving
        self.canSave = canSave
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
            BackupConfigEditorToolbarTitle(kind: kind, title: title)

            if isEditMode || isCancellable {
                BackupConfigEditorCancelItem(
                    hasUnsavedChanges: hasUnsavedChanges,
                    isConfirmationPresented: $isDiscardConfirmationPresented,
                    onDismiss: onClose
                )
            }

            saveItem
        }
        .dragDismissAttempt(isEnabled: hasUnsavedChanges) {
            // Anchor to the cancel button if there is one; fall back to a centered alert.
            if isEditMode || isCancellable {
                isDiscardConfirmationPresented = true
            } else {
                isAddModeDiscardAlertPresented = true
            }
        }
        .backupConfigEditorUnsavedChangesAlert(
            isPresented: $isAddModeDiscardAlertPresented,
            onDiscard: onClose
        )
    }

    @ToolbarContentBuilder
    private var saveItem: some ToolbarContent {
        if let confirmLabel {
            ToolbarSaveItem(action: onSave)
                .label(confirmLabel)
                .loading(isSaving)
                .disabled(!canSave)
        } else {
            ToolbarSaveItem(action: onSave)
                .loading(isSaving)
                .disabled(!canSave)
        }
    }

    func editMode(_ enabled: Bool = true) -> Self {
        var instance = self
        instance.isEditMode = enabled
        return instance
    }

    func confirmLabel(_ label: Text) -> Self {
        var instance = self
        instance.confirmLabel = label
        return instance
    }

    func cancellable(_ flag: Bool = true) -> Self {
        var instance = self
        instance.isCancellable = flag
        return instance
    }
}

extension BackupConfigEditorForm {

    init(
        kind: BackupSyncService,
        title: LocalizedStringResource,
        hasUnsavedChanges: Bool,
        isSaving: Bool,
        canSave: Bool,
        onSave: @escaping () -> Void,
        onClose: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.init(
            kind: kind,
            title: Text(title),
            hasUnsavedChanges: hasUnsavedChanges,
            isSaving: isSaving,
            canSave: canSave,
            onSave: onSave,
            onClose: onClose,
            content: content
        )
    }

    func confirmLabel(_ label: LocalizedStringResource) -> Self {
        confirmLabel(Text(label))
    }
}
