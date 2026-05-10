// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Backup
import CommonUI

enum BackupConfigsAddDestination: RouterDestination {
    /// `onClose` receives the new config's UUID on a successful save (the View writes it
    /// into `savedConfigID` so the parent's matched-zoom destination flips to the new
    /// row before the sheet animates away), or `nil` on plain cancel/dismiss. The
    /// closure itself is responsible for dismissing the sheet — the form view doesn't
    /// know it's hosted in one.
    case webDAV(onClose: (UUID?) -> Void)
    case s3(onClose: (UUID?) -> Void)

    /// Explicit `String` id (not `Self`) because the associated `onClose` closures
    /// aren't `Hashable`. Cases without payloads are still distinct — switch ignores
    /// associated values.
    var id: String {
        switch self {
        case .webDAV: "webDAV"
        case .s3: "s3"
        }
    }
}

struct BackupConfigsAddView: View {
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
    @State private var destination: BackupConfigsAddDestination?
    @Namespace private var transitionNamespace

    init(canAddiCloud: Bool, onAddiCloud: @escaping () -> UUID?, savedConfigID: Binding<UUID?>) {
        self._canAddiCloud = State(initialValue: canAddiCloud)
        self.onAddiCloud = onAddiCloud
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
                    if canAddiCloud {
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
                        action: { destination = .webDAV(onClose: handleFormClose) }
                    )
                    .matchedZoomSource(id: BackupConfigsAddRouter.webDAVSourceID, in: transitionNamespace)
                    BackupConfigsAddProviderRow(
                        kind: .s3,
                        title: .backupConfigsProviderS3,
                        subtitle: .backupConfigsProviderS3Description,
                        action: { destination = .s3(onClose: handleFormClose) }
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
                destination: $destination
            )
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
            BackupConfigsAddView(
                canAddiCloud: true,
                onAddiCloud: { nil },
                savedConfigID: .constant(nil)
            )
            .presentationDetents([.large])
        }
}
