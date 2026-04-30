// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Backup
import CommonUI

struct BackupConfigsView: View {

    @State
    var presenter: BackupConfigsPresenter

    @Namespace private var transitionNamespace

    var body: some View {
        SettingsDetailsForm(.settingsEntryCloudSync) {
            if !presenter.isEmpty {
                Section {
                    Button(role: presenter.isSyncing ? .cancel : nil) {
                        if presenter.isSyncing {
                            presenter.onCancelSyncAll()
                        } else {
                            presenter.onSyncNow()
                        }
                    } label: {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: presenter.isSyncing ? "xmark" : "arrow.clockwise")
                            Text(presenter.isSyncing
                                 ? .backupConfigsCancelSyncButton
                                 : .backupConfigsSyncAllNowButton)
                                .font(.body)
                            Spacer()
                            if presenter.isSyncing {
                                ProgressView()
                            }
                        }
                        .contentShape(Rectangle())
                    }
                }
            }

            ForEach(presenter.rows) { row in
                Section {
                    BackupConfigRowView(
                        row: row,
                        onSyncNow: { presenter.onSyncRow(row) },
                        onEdit: { presenter.onSelect(row) },
                        onRemove: { presenter.onDelete(row) }
                    )
                    .matchedZoomSource(
                        id: BackupConfigsRouter.editSourceID(for: row.id),
                        in: transitionNamespace
                    )
                } footer: {
                    HStack(spacing: 6) {
                        if row.isSyncing {
                            ProgressView()
                                .controlSize(.mini)
                        }
                        Text(row.statusText)
                    }
                    .settingsFooter()
                }
            }
        } header: {
            SettingsHeaderView(
                icon: .sync,
                title: Text(.settingsCloudSyncTitle),
                description: Text(.settingsCloudSyncDescription)
            )
        }
        .overlay {
            if presenter.isEmpty {
                EmptyListView(.backupConfigsEmptyDescription)
            }
        }
        .animation(.default, value: presenter.rows)
        .onAppear {
            presenter.onAppear()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if #available(iOS 26, *) {
                    addMenu
                        .buttonStyle(.borderedProminent)
                } else {
                    addMenu
                }
            }
        }
        .router(
            router: BackupConfigsRouter(transitionNamespace: transitionNamespace),
            destination: $presenter.destination
        )
        // The add/edit screens are presented as `.sheet`, which doesn't unmount the parent
        // view — `.onAppear` therefore doesn't fire on dismissal. Refresh the rows when the
        // destination clears so newly-added or edited configs become visible.
        .onChange(of: presenter.destination?.id) { _, newValue in
            if newValue == nil {
                presenter.onAppear()
            }
        }
    }

    private var addMenu: some View {
        Menu {
            if presenter.canAddiCloud {
                Button {
                    presenter.onChooseProvider(.iCloud)
                } label: {
                    Label(.backupConfigsProviderIcloud, systemImage: "icloud.fill")
                }
            }
            Button {
                presenter.onChooseProvider(.webDAV)
            } label: {
                Label(.backupConfigsProviderWebdav, systemImage: "server.rack")
            }
            Button {
                presenter.onChooseProvider(.s3)
            } label: {
                Label(.backupConfigsProviderS3, systemImage: "externaldrive.fill.badge.icloud")
            }
        } label: {
            Image(systemName: "plus")
                .accessibilityLabel(Text(.backupConfigsAddButton))
        }
        .matchedZoomSource(id: BackupConfigsRouter.addWebDAVSourceID, in: transitionNamespace)
        .matchedZoomSource(id: BackupConfigsRouter.addS3SourceID, in: transitionNamespace)
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
}

private struct BackupConfigRowView: View {
    let row: BackupConfigRowItem
    let onSyncNow: () -> Void
    let onEdit: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            SettingsIconView(icon: row.icon)
                .controlSize(.small)

            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                    .foregroundStyle(.neutral950)
                    .font(.body)
                if let subtitle = row.subtitle {
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
                Image(systemName: "ellipsis")
                    .foregroundStyle(.neutral500)
                    .frame(width: 40, height: 40, alignment: .trailing)
            }
            .tint(nil)
        }
    }
}

#Preview {
    NavigationStack {
        BackupConfigsRouter.buildView()
    }
}
