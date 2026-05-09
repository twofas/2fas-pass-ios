// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Backup
import CommonUI

struct BackupProviderPickerView: View {
    let canAddiCloud: Bool
    let onAddiCloud: () -> Void

    // Captured at the picker root (sheet root), so calling it dismisses the entire sheet
    // — even when the form is currently pushed on top of the picker. The form's own
    // `\.dismiss` (a pop action inside the nav stack) is intentionally separate from this.
    @Environment(\.dismiss) private var dismissSheet
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedForm: ProviderForm?

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
                    BackupProviderPickerRow(
                        kind: .s3,
                        title: .backupConfigsProviderS3,
                        subtitle: .backupConfigsProviderS3Description,
                        action: { selectedForm = .s3 }
                    )
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
                            onClose: { dismissSheet() }
                        )
                    )
                case .s3:
                    BackupS3ConfigView(
                        presenter: .init(
                            interactor: ModuleInteractorFactory.shared.backupS3ConfigModuleInteractor(configID: nil),
                            configID: nil,
                            onClose: { dismissSheet() }
                        )
                    )
                }
            }
        }
    }

    private func handleiCloudTap() {
        dismissSheet()
        onAddiCloud()
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
                onAddiCloud: {}
            )
            .presentationDetents([.large])
        }
}
