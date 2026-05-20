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

    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var transitionNamespace

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HeaderContentView(
                    title: Text(.backupConfigsProviderPickerTitle),
                    subtitle: Text(.backupConfigsProviderPickerSubtitle),
                    icon: Image(systemName: "externaldrive.fill.badge.timemachine")
                )
                .padding(.vertical, Spacing.l)

                VStack(spacing: Spacing.m) {
                    if presenter.canAddiCloud {
                        BackupConfigsAddProviderCell(
                            kind: .iCloud,
                            title: .backupConfigsProviderIcloudTitle,
                            subtitle: .backupConfigsProviderIcloudDescription,
                            action: presenter.selectIcloud
                        )
                        .hideChevron()
                    }
                    
                    BackupConfigsAddProviderCell(
                        kind: .webDAV,
                        title: .backupConfigsProviderWebdavTitle,
                        subtitle: .backupConfigsProviderWebdavDescription,
                        action: presenter.selectWebDAV
                    )
                    .matchedZoomSource(id: BackupConfigsAddRouter.webDAVSourceID, in: transitionNamespace)
                    
                    BackupConfigsAddProviderCell(
                        kind: .s3,
                        title: .backupConfigsProviderS3Title,
                        subtitle: .backupConfigsProviderS3Description,
                        action: presenter.selectS3
                    )
                    .matchedZoomSource(id: BackupConfigsAddRouter.s3SourceID, in: transitionNamespace)
                }
                .padding(.vertical, Spacing.xll)

                Spacer()
            }
            .padding(.horizontal, Spacing.xl)
            .readableContentMargins()
            .background(background)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarCancelButton(action: presenter.cancel)
                }
            }
            .router(
                router: BackupConfigsAddRouter(transitionNamespace: transitionNamespace),
                destination: $presenter.destination
            )
        }
    }

    private var background: Color {
        colorScheme == .dark
            ? Color(UIColor.systemGroupedBackground)
            : Color(.mainBackground)
    }
}

private struct BackupConfigsAddProviderCell: View {
    let kind: BackupSyncService
    let title: LocalizedStringResource
    let subtitle: LocalizedStringResource
    let action: () -> Void

    private var showsChevron: Bool = true

    init(
        kind: BackupSyncService,
        title: LocalizedStringResource,
        subtitle: LocalizedStringResource,
        action: @escaping () -> Void
    ) {
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            OptionButtonLabel(
                title: Text(title),
                subtitle: Text(subtitle),
                icon: { BackupServiceIcon(kind: kind).controlSize(.large) }
            )
            .hideChevron(!showsChevron)
        }
        .buttonStyle(.option)
    }
    
    func hideChevron(_ hide: Bool = true) -> Self {
        var instance = self
        instance.showsChevron = !hide
        return instance
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            BackupConfigsAddView(
                presenter: BackupConfigsAddPresenter(
                    interactor: PreviewModuleInteractor(),
                    onClose: { _ in }
                )
            )
            .presentationDetents([.large])
        }
}

@MainActor
private final class PreviewModuleInteractor: BackupConfigsAddModuleInteracting {
    let canAddiCloud = true
    func addiCloud() -> BackupConfig.ID? { nil }
}
