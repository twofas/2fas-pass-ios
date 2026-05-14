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
    @State private var headerBottomY: CGFloat = 0
    @State private var formSize: CGSize = .zero

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
        } header: {
            SettingsHeaderView(
                icon: .sync,
                title: Text(.settingsCloudSyncTitle),
                description: Text(.settingsCloudSyncDescription)
            )
            .onGeometryChange(for: CGFloat.self, of: { proxy in
                proxy.frame(in: .global).maxY
            }, action: {
                headerBottomY = $0
            })
        }
        .onGeometryChange(for: CGSize.self, of: { proxy in
            let size = proxy.size
            return CGSize(
                width: size.width,
                height: size.height + proxy.safeAreaInsets.top
            )
            
        }, action: {
            formSize = $0
        })
        .overlay(alignment: .top) {
            if presenter.isEmpty {
                EmptyListView(.backupConfigsEmptyDescription)
                    .listRowBackground(Color.clear)
                    .position(x: formSize.width / 2, y: headerBottomY + (formSize.height - headerBottomY) / 2.1)
                    .ignoresSafeArea()
            }
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
            router: BackupConfigsRouter(
                transitionNamespace: transitionNamespace,
                presenter: presenter
            ),
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
    }

    private var addButton: some View {
        Button {
            presenter.onAddPressed()
        } label: {
            Image(systemName: "plus")
                .accessibilityLabel(Text(.backupConfigsAddButton))
                .foregroundStyle(.white)
        }
        .disabled(presenter.isSyncing)
        .matchedZoomSource(id: BackupConfigsRouter.pickerSourceID, in: transitionNamespace)
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
            BackupServiceIcon(kind: row.kind)

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
