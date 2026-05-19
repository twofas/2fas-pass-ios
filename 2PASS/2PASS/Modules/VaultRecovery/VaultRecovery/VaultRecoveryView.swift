// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Backup
import CommonUI

struct VaultRecoveryView: View {

    @State
    var presenter: VaultRecoveryPresenter

    @Namespace private var transitionNamespace

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HeaderContentView(
                    title: Text(.restoreVaultSourceTitle),
                    subtitle: Text(.restoreVaultSourceDescription),
                    icon: Image(systemName: "externaldrive.fill.badge.timemachine")
                )
                .padding(.vertical, Spacing.l)
                
                VStack(spacing: Spacing.m) {
                    Button {
                        presenter.onRestoreFromCloud()
                    } label: {
                        OptionButtonLabel(
                            title: Text(.restoreVaultSourceOptionIcloud),
                            subtitle: Text(.restoreVaultSourceOptionIcloudDescription),
                            icon: { BackupServiceIcon(kind: .iCloud).controlSize(.large) }
                        )
                    }
                    .buttonStyle(.option)
                    .matchedZoomSource(id: VaultRecoveryRouter.iCloudSourceID, in: transitionNamespace)
                    
                    Button {
                        presenter.onRestoreFromFile()
                    } label: {
                        OptionButtonLabel(
                            title: Text(.restoreVaultSourceOptionFile),
                            subtitle: Text(.restoreVaultSourceOptionFileDescription),
                            icon: {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 29))
                            }
                        )
                    }
                    .buttonStyle(.option)
                    
                    Button {
                        presenter.onRestoreFromWebDAV()
                    } label: {
                        OptionButtonLabel(
                            title: Text(.restoreVaultSourceOptionWebdav),
                            subtitle: Text(.restoreVaultSourceOptionWebdavDescription),
                            icon: { BackupServiceIcon(kind: .webDAV).controlSize(.large) }
                        )
                    }
                    .buttonStyle(.option)
                    .matchedZoomSource(id: VaultRecoveryRouter.webDAVSourceID, in: transitionNamespace)
                    
                    Button {
                        presenter.onRestoreFromS3()
                    } label: {
                        OptionButtonLabel(
                            title: Text(.restoreVaultSourceOptionS3),
                            subtitle: Text(.restoreVaultSourceOptionS3Description),
                            icon: { BackupServiceIcon(kind: .s3).controlSize(.large) }
                        )
                    }
                    .buttonStyle(.option)
                    .matchedZoomSource(id: VaultRecoveryRouter.s3SourceID, in: transitionNamespace)
                }
                .padding(.vertical, Spacing.xll)
            }
        }
        .contentMargins(.horizontal, Spacing.xl)
        .scrollBounceBehavior(.basedOnSize)
        .router(
            router: VaultRecoveryRouter(transitionNamespace: transitionNamespace),
            destination: $presenter.destination
        )
        .background(.mainBackground)
        .readableContentMargins()
    }
}

#Preview {
    VaultRecoveryRouter.buildView()
}
