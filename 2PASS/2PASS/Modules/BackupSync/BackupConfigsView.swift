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
    @State private var isProviderPickerPresented = false
    @State private var pendingProviderChoice: SyncServiceKind?

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
        }
        .contentMargins(.bottom, Spacing.l, for: .scrollContent)
        .overlay {
            if presenter.isEmpty {
                EmptyListView(.backupConfigsEmptyDescription)
            }
        }
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
        // The add/edit screens are presented as `.sheet`, which doesn't unmount the parent
        // view — `.onAppear` therefore doesn't fire on dismissal. Refresh the rows when the
        // destination clears so newly-added or edited configs become visible.
        .onChange(of: presenter.destination?.id) { _, newValue in
            if newValue == nil {
                presenter.onAppear()
            }
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
        .popover(isPresented: $isProviderPickerPresented) {
            providerPicker
                .presentationCompactAdaptation(.popover)
                .onDisappear(perform: handlePendingProviderChoice)
        }
        .disabled(presenter.isSyncing)
        .matchedZoomSource(id: BackupConfigsRouter.addWebDAVSourceID, in: transitionNamespace)
        .matchedZoomSource(id: BackupConfigsRouter.addS3SourceID, in: transitionNamespace)
    }

    private func handlePendingProviderChoice() {
        // Run after popover dismissal so the next sheet presentation finds an empty
        // UIKit presentedViewController slot — otherwise we hit "already presenting".
        guard let kind = pendingProviderChoice else { return }
        pendingProviderChoice = nil
        presenter.onChooseProvider(kind)
    }

    private var providerPicker: some View {
        VStack(alignment: .leading, spacing: 0) {
            if presenter.canAddiCloud {
                providerPickerButton(.iCloud, title: .backupConfigsProviderIcloud)
            }
            providerPickerButton(.webDAV, title: .backupConfigsProviderWebdav)
            providerPickerButton(.s3, title: .backupConfigsProviderS3)
        }
        .padding(Spacing.m)
        .frame(minWidth: 200)
    }

    private func providerPickerButton(
        _ kind: SyncServiceKind,
        title: LocalizedStringResource
    ) -> some View {
        Button {
            pendingProviderChoice = kind
            isProviderPickerPresented = false
        } label: {
            HStack(spacing: 12) {
                BackupConfigIcon(kind: kind)
                Text(title)
                    .foregroundStyle(.neutral950)
                    .font(.body)
            }
            .padding(Spacing.s)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                MenuEllipsisLabel()
            }
            .disabled(!isMenuEnabled)
            .tint(nil)
        }
    }
}

private struct BackupConfigIcon: View {
    let kind: SyncServiceKind

    @Environment(\.colorScheme) private var colorScheme

    private let size: CGFloat = 40
    private var cornerRadius: CGFloat { size * 0.25 }

    var body: some View {
        content
            .frame(width: size, height: size)
            .background(background)
    }

    @ViewBuilder
    private var content: some View {
        switch kind {
        case .iCloud:
            Image(.icloudIcon)
                .resizable()
                .scaledToFit()
                .frame(width: size * 0.7, height: size * 0.7)
        case .webDAV:
            Image(systemName: "externaldrive")
                .renderingMode(.template)
                .font(.system(size: size * 0.5))
                .foregroundStyle(colorScheme == .dark ? Color.neutral950 : .neutral50)
        case .s3:
            // AWS asset is a self-contained green tile — clip to the same corner radius.
            Image(.s3Icon)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    @ViewBuilder
    private var background: some View {
        switch kind {
        case .iCloud:
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(colorScheme == .dark ? .neutral800 : .neutral200, lineWidth: 0.5)
                .fill(colorScheme == .dark ? .baseStatic0 : .clear)
        case .webDAV:
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(.accent)
        case .s3:
            Color.clear
        }
    }
}

#Preview {
    NavigationStack {
        BackupConfigsRouter.buildView()
    }
}
