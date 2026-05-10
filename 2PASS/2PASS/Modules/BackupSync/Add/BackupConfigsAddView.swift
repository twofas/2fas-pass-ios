// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Backup
import CommonUI

struct BackupConfigsAddView: View {

    @State
    var presenter: BackupConfigsAddPresenter

    /// Written when the form completes successfully so the parent's matched-zoom
    /// destination can switch from the `+` button source to the new row's source ID
    /// before the sheet dismisses.
    @Binding var savedConfigID: UUID?

    // Captured at the picker root (sheet root), so calling it dismisses the entire sheet
    // — even when the form is currently pushed on top of the picker. The form's own
    // `\.dismiss` (a pop action inside the nav stack) is intentionally separate from this.
    @Environment(\.dismiss) private var dismissSheet
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var transitionNamespace

    init(presenter: BackupConfigsAddPresenter, savedConfigID: Binding<UUID?>) {
        self._presenter = State(wrappedValue: presenter)
        self._savedConfigID = savedConfigID
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
                    if presenter.canAddiCloud {
                        BackupConfigsAddProviderRow(
                            kind: .iCloud,
                            title: .backupConfigsProviderIcloud,
                            subtitle: .backupConfigsProviderIcloudDescription,
                            action: handleiCloudTap
                        )
                        .hideChevron()
                    }
                    BackupConfigsAddProviderRow(
                        kind: .webDAV,
                        title: .backupConfigsProviderWebdav,
                        subtitle: .backupConfigsProviderWebdavDescription,
                        action: { presenter.selectWebDAV(onClose: handleFormClose) }
                    )
                    .matchedZoomSource(id: BackupConfigsAddRouter.webDAVSourceID, in: transitionNamespace)
                    BackupConfigsAddProviderRow(
                        kind: .s3,
                        title: .backupConfigsProviderS3,
                        subtitle: .backupConfigsProviderS3Description,
                        action: { presenter.selectS3(onClose: handleFormClose) }
                    )
                    .matchedZoomSource(id: BackupConfigsAddRouter.s3SourceID, in: transitionNamespace)
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
            .router(
                router: BackupConfigsAddRouter(transitionNamespace: transitionNamespace),
                destination: $presenter.destination
            )
        }
    }

    private func handleiCloudTap() {
        // Add the iCloud config FIRST (synchronous via the presenter → parent's
        // `addiCloud` callback → interactor → `withAnimation { reload() }`), capture its
        // UUID, set `savedConfigID` to swap the parent's matched-zoom destination to the
        // new row's source ID, THEN dismiss. Mirrors the form-save flow so iCloud also
        // zooms into its new row.
        if let newID = presenter.performIcloudAdd() {
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

private struct BackupConfigsAddProviderRow: View {
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
            BackupConfigsAddRouter.buildView(
                canAddiCloud: true,
                addiCloud: { nil },
                savedConfigID: .constant(nil)
            )
            .presentationDetents([.large])
        }
}
