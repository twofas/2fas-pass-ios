// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Backup
import CommonUI

struct BackupConfigsView: View {

    @State
    var presenter: BackupConfigsPresenter

    @Namespace private var transitionNamespace
    @State private var isProviderPickerPresented = false
    /// Set by the picker when its inner form saves successfully — the saved config's UUID.
    /// Drives the sheet's matched-zoom destination to point at the new row instead of the
    /// `+` button so the dismiss animates the sheet down INTO the freshly-added row.
    /// Reset on sheet dismissal so the next picker open starts fresh (zoom back to button
    /// for cancel/iCloud paths).
    @State private var savedConfigIDFromPicker: UUID?

    private static let providerPickerSourceID = "backupConfigs.add.picker"

    private var pickerZoomDestinationID: String {
        if let savedConfigIDFromPicker {
            return BackupConfigsRouter.editSourceID(for: savedConfigIDFromPicker)
        }
        return Self.providerPickerSourceID
    }

    var body: some View {
        SettingsDetailsForm(.settingsEntryCloudSync) {
            if !presenter.isEmpty {
                Section {
                    Button(role: presenter.isSyncing ? .cancel : nil) {
                        if presenter.isSyncing {
                            presenter.onCancelSync()
                        } else {
                            presenter.onSyncAllNow()
                        }
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Text(presenter.isSyncing
                                 ? .backupConfigsCancelSyncButton
                                 : .backupConfigsSyncAllNowButton)
                                .font(.body)
                            
                            Spacer()
                            
                            if !presenter.isSyncing && presenter.errorCount > 0 {
                                BadgeView(value: presenter.errorCount)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                }
                .animation(.default, value: presenter.isSyncing)
            }

            ForEach(presenter.rows) { row in
                Section {
                    BackupConfigRowView(
                        row: row,
                        isMenuEnabled: !presenter.isSyncing,
                        onSyncNow: { presenter.onSyncRow(row) },
                        onEdit: { presenter.onSelect(row) },
                        onRemove: { presenter.onDelete(row) }
                    )
                    .matchedZoomSource(
                        id: BackupConfigsRouter.editSourceID(for: row.id),
                        in: transitionNamespace
                    )
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        if let errorText = row.errorText {
                            Text(errorText)
                                .foregroundStyle(.danger500)
                        }
                        HStack(spacing: 6) {
                            if row.isSyncing {
                                ProgressView()
                                    .controlSize(.mini)
                            }
                            Text(row.statusText)
                        }
                    }
                    .settingsFooter()
                }
            }
            
            if presenter.isEmpty {
                EmptyListView(.backupConfigsEmptyDescription)
                    .listRowBackground(Color.clear)
                    .padding(.top, 32)
            }
        } header: {
            SettingsHeaderView(
                icon: .sync,
                title: Text(.settingsCloudSyncTitle),
                description: Text(.settingsCloudSyncDescription)
            )
        }
        .contentMargins(.bottom, Spacing.l, for: .scrollContent)
        .animation(.default, value: presenter.rows)
        .onAppear {
            presenter.onAppear()
        }
        .onDisappear {
            presenter.onDisappear()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if #available(iOS 26, *) {
                    addButton
                        .buttonStyle(.glassProminent)
                        .labelStyle(.titleOnly)
                        .tint(.accent)
                        .foregroundStyle(.white)
                } else {
                    addButton
                }
            }
        }
        .router(
            router: BackupConfigsRouter(transitionNamespace: transitionNamespace),
            destination: $presenter.destination
        )
        // Edit screens are presented as `.sheet`, which doesn't unmount this view, so
        // `.onAppear` doesn't fire on dismissal. Refresh the rows when the destination
        // clears so edited configs become visible. (Add flows are handled inside the picker
        // sheet and trigger reload via `BackupConfigsDidChange` notification instead.)
        .onChange(of: presenter.destination?.id) { _, newValue in
            if newValue == nil {
                presenter.onAppear()
            }
        }
        // Sheet attached at the body level (not inside `addButton`) so its content's
        // environment isn't polluted by the toolbar's `.tint(.accent)` / `.foregroundStyle(.white)`
        // — those cascade into sheets attached inside their styling chain.
        .sheet(isPresented: $isProviderPickerPresented, onDismiss: {
            // Reset so the next picker open starts back at the `+`-button zoom destination —
            // otherwise a stale ID from the previous save would target the wrong row.
            savedConfigIDFromPicker = nil
        }) {
            BackupProviderPickerView(
                canAddiCloud: presenter.canAddiCloud,
                onAddiCloud: { presenter.addiCloud() },
                savedConfigID: $savedConfigIDFromPicker
            )
            .presentationDetents([.large])
            .matchedZoomDestination(id: pickerZoomDestinationID, in: transitionNamespace)
        }
    }

    private var addButton: some View {
        Button {
            isProviderPickerPresented = true
        } label: {
            Image(systemName: "plus")
                .accessibilityLabel(Text(.backupConfigsAddButton))
                .foregroundStyle(.white)
        }
        .disabled(presenter.isSyncing)
        .matchedZoomSource(id: Self.providerPickerSourceID, in: transitionNamespace)
    }
}

private extension View {
    @ViewBuilder
    func matchedZoomSource(id: String, in namespace: Namespace.ID) -> some View {
        if #available(iOS 26.0, *) {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self
        }
    }

    @ViewBuilder
    func matchedZoomDestination(id: String, in namespace: Namespace.ID) -> some View {
        if #available(iOS 26.0, *) {
            self.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}

private struct BackupConfigRowView: View {
    let row: BackupConfigRowItem
    let isMenuEnabled: Bool
    let onSyncNow: () -> Void
    let onEdit: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            BackupConfigIcon(kind: row.kind)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .foregroundStyle(.neutral950)
                    .font(.body)
                if let subtitle = row.subtitle, subtitle.isEmpty == false {
                    Text(subtitle)
                        .foregroundStyle(.neutral500)
                        .font(.footnote)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 0)

            Menu {
                Button {
                    onSyncNow()
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text(.backupConfigsSyncNowButton)
                    }
                }

                if row.kind != .iCloud {
                    Button {
                        onEdit()
                    } label: {
                        HStack {
                            Image(systemName: "pencil")
                            Text(.commonEdit)
                        }
                    }
                }

                Button(role: .destructive) {
                    onRemove()
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text(.commonDelete)
                    }
                }
            } label: {
                MenuEllipsisLabel()
            }
            .disabled(!isMenuEnabled)
            .tint(nil)
        }
    }
}

#Preview {
    NavigationStack {
        BackupConfigsRouter.buildView()
    }
}
