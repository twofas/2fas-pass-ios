// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Backup
import CommonUI

struct BackupProviderPickerView: View {
    /// Returns the new iCloud config's UUID if one was created (parent calls
    /// `presenter.addiCloud()` which forwards the interactor's returned UUID). The picker
    /// uses it to drive the same matched-zoom-back-to-new-row animation as the form path.
    let onAddiCloud: () -> UUID?
    /// Written when the form completes successfully so the parent's matched-zoom
    /// destination can switch from the `+` button source to the new row's source ID
    /// before the sheet dismisses.
    @Binding var savedConfigID: UUID?

    /// Frozen at picker open time so the iCloud row doesn't vanish from the picker
    /// mid-dismiss. Without this, the moment `presenter.addiCloud()` runs the parent's
    /// `canAddiCloud` flips to `false`, SwiftUI re-renders the picker, and the iCloud row
    /// disappears just as the sheet is animating away — visible glitch. State.initialValue
    /// is only used on first mount; subsequent re-creations of the struct preserve the
    /// captured value. When the sheet closes & reopens, a new mount captures fresh.
    @State private var canAddiCloud: Bool

    // Captured at the picker root (sheet root), so calling it dismisses the entire sheet
    // — even when the form is currently pushed on top of the picker. The form's own
    // `\.dismiss` (a pop action inside the nav stack) is intentionally separate from this.
    @Environment(\.dismiss) private var dismissSheet
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedForm: ProviderForm?
    @Namespace private var transitionNamespace

    private static let webDAVSourceID = "backupConfigs.providerPicker.webDAV"
    private static let s3SourceID = "backupConfigs.providerPicker.s3"

    init(canAddiCloud: Bool, onAddiCloud: @escaping () -> UUID?, savedConfigID: Binding<UUID?>) {
        self._canAddiCloud = State(initialValue: canAddiCloud)
        self.onAddiCloud = onAddiCloud
        self._savedConfigID = savedConfigID
    }

    private enum ProviderForm: Hashable, Identifiable {
        case webDAV
        case s3
        var id: Self { self }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HeaderContentView(
                    title: Text(.backupConfigsProviderPickerTitle),
                    subtitle: Text(.backupConfigsProviderPickerSubtitle),
                    icon: {
                        Image(systemName: "externaldrive.fill.badge.timemachine")
                    }
                )
                .padding(.vertical, Spacing.l)

                VStack(spacing: Spacing.m) {
                    if canAddiCloud {
                        BackupProviderPickerRow(
                            kind: .iCloud,
                            title: .backupConfigsProviderIcloud,
                            subtitle: .backupConfigsProviderIcloudDescription,
                            action: handleiCloudTap
                        )
                        .hideChevron()
                    }
                    BackupProviderPickerRow(
                        kind: .webDAV,
                        title: .backupConfigsProviderWebdav,
                        subtitle: .backupConfigsProviderWebdavDescription,
                        action: { selectedForm = .webDAV }
                    )
                    .matchedZoomSource(id: Self.webDAVSourceID, in: transitionNamespace)
                    BackupProviderPickerRow(
                        kind: .s3,
                        title: .backupConfigsProviderS3,
                        subtitle: .backupConfigsProviderS3Description,
                        action: { selectedForm = .s3 }
                    )
                    .matchedZoomSource(id: Self.s3SourceID, in: transitionNamespace)
                }
                .padding(.vertical, Spacing.xll)

                Spacer()
            }
            .padding(.horizontal, Spacing.xl)
            .background(background)
            .readableContentMargins()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarCancelButton { dismissSheet() }
                }
            }
            .navigationDestination(item: $selectedForm) { form in
                switch form {
                case .webDAV:
                    BackupWebDAVConfigView(
                        presenter: .init(
                            interactor: ModuleInteractorFactory.shared.backupWebDAVConfigModuleInteractor(configID: nil),
                            configID: nil,
                            onClose: handleFormClose
                        )
                    )
                    .matchedZoomDestination(id: Self.webDAVSourceID, in: transitionNamespace)
                case .s3:
                    BackupS3ConfigView(
                        presenter: .init(
                            interactor: ModuleInteractorFactory.shared.backupS3ConfigModuleInteractor(configID: nil),
                            configID: nil,
                            onClose: handleFormClose
                        )
                    )
                    .matchedZoomDestination(id: Self.s3SourceID, in: transitionNamespace)
                }
            }
        }
    }

    private func handleiCloudTap() {
        // Add the iCloud config FIRST (synchronous via parent's `presenter.addiCloud()` →
        // interactor → `withAnimation { reload() }`), capture its UUID, set `savedConfigID`
        // to swap the parent's matched-zoom destination to the new row's source ID, THEN
        // dismiss. Mirrors the form-save flow so iCloud also zooms into its new row.
        if let newID = onAddiCloud() {
            savedConfigID = newID
        }
        
        Task { @MainActor in
            dismissSheet()
        }
    }

    private func handleFormClose(_ configID: UUID?) {
        // Set BEFORE dismiss so SwiftUI re-evaluates the parent's `.matchedZoomDestination`
        // ID with the new row's source ID before the sheet starts animating away.
        if let configID {
            savedConfigID = configID
        }
        Task { @MainActor in
            dismissSheet()
        }
    }

    private var background: Color {
        colorScheme == .dark
            ? Color(UIColor.systemGroupedBackground)
            : Color(.mainBackground)
    }
}

private struct BackupProviderPickerRow: View {
    let kind: SyncServiceKind
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    let action: () -> Void

    private var showsChevron: Bool = true

    init(
        kind: SyncServiceKind,
        title: LocalizedStringResource,
        subtitle: LocalizedStringResource,
        action: @escaping () -> Void
    ) {
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }

    func hideChevron(_ hide: Bool = true) -> Self {
        var instance = self
        instance.showsChevron = !hide
        return instance
    }

    var body: some View {
        Button(action: action) {
            OptionButtonLabel(
                title: Text(title),
                subtitle: Text(subtitle),
                icon: { BackupConfigIcon(kind: kind, size: 64) }
            )
            .hideChevron(!showsChevron)
        }
        .buttonStyle(.option)
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            BackupProviderPickerView(
                canAddiCloud: true,
                onAddiCloud: { nil },
                savedConfigID: .constant(nil)
            )
            .presentationDetents([.large])
        }
}
