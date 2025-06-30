// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct VaultRecoveryView: View {
    
    @State
    var presenter: VaultRecoveryPresenter
    
    var body: some View {
        VStack(spacing: 0) {
            HeaderContentView(
                title: Text(T.restoreVaultSourceTitle.localizedKey),
                subtitle: Text(T.restoreVaultSourceDescription.localizedKey),
                icon: Image(systemName: "externaldrive.fill.badge.timemachine")
            )
            .padding(.vertical, Spacing.l)
            
            VStack(spacing: Spacing.m) {
                Button {
                    presenter.onRestoreFromCloud()
                } label: {
                    OptionButtonLabel(
                        title: Text(T.restoreVaultSourceOptionIcloud.localizedKey),
                        subtitle: Text(T.restoreVaultSourceOptionIcloudDescription.localizedKey),
                        icon: {
                            Image(.iCloudLogo)
                        }
                    )
                }
                .buttonStyle(.option)
                
                Button {
                    presenter.onRestoreFromFile()
                } label: {
                    OptionButtonLabel(
                        title: Text(T.restoreVaultSourceOptionFile.localizedKey),
                        subtitle: Text(T.restoreVaultSourceOptionFileDescription.localizedKey),
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
                        title: Text(T.restoreVaultSourceOptionWebdav.localizedKey),
                        subtitle: Text(T.restoreVaultSourceOptionWebdavDescription.localizedKey),
                        icon: {
                            Image(systemName: "cloud.fill")
                                .font(.system(size: 33))
                        }
                    )
                }
                .buttonStyle(.option)
            }
            .padding(.vertical, Spacing.xll)
            
            Spacer()
        }
        .padding(.horizontal, Spacing.xl)
        .router(router: VaultRecoveryRouter(), destination: $presenter.destination)
        .background(Color(Asset.mainBackgroundColor.color))
        .readableContentMargins()
    }
}

#Preview {
    VaultRecoveryRouter.buildView()
}
