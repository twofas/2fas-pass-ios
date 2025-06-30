// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import PhotosUI
import Common
import CommonUI

struct VaultRecoveryiCloudVaultSelectionView: View {
    
    @State
    var presenter: VaultRecoveryiCloudVaultSelectionPresenter
    
    @Environment(\.dismiss)
    private var dismiss
    
    var body: some View {
        ZStack {
            switch presenter.state {
            case .loading:
                ProgressView()
                    .progressViewStyle(.circular)
                    .controlSize(.large)
                    .tint(nil)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
            case .error(let string):
                ResultView(
                    kind: .failure,
                    title: Text(T.restoreIcloudFilesError.localizedKey),
                    description: Text(string),
                    action: {
                        Button(T.commonTryAgain.localizedKey) {
                            presenter.retry()
                        }
                    }
                )
                
            case .list(let vaults):
                list(for: vaults)
            case .empty:
                EmptyListView(T.restoreCloudFilesEmptyDescription.localizedKey)
            }
        }
        .animation(.easeInOut(duration: 0.1), value: presenter.state)
        .navigationTitle(T.restoreIcloudFilesTitle.localizedKey)
        .navigationBarTitleDisplayMode(.inline)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(T.commonCancel.localizedKey) {
                    dismiss()
                }
            }
        }
        .onAppear {
            presenter.onAppear()
        }
    }
        
    @ViewBuilder
    private func list(for vaults: [VaultRecoveryiCloudVaultSelectionEntry]) -> some View {
        List {
            ForEach(Array(vaults.enumerated()), id: \.1) { index, vault in
                Section {
                    Button {
                        presenter.onSelect(vault: vault.vaultRawData)
                    } label: {
                        VaultRecoveryCell(
                            vaultID: vault.id.uuidString,
                            deviceName: vault.deviceName,
                            updatedAt: vault.updatedAt,
                            canBeUsed: vault.canBeUsed
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(!vault.canBeUsed)
                    
                } header: {
                    if index == 0 {
                        Text(T.restoreCloudFilesHeader.localizedKey)
                            .padding(.top, Spacing.s)
                    }
                }
            }
        }
        .listSectionSpacing(Spacing.s)
        .listStyle(.insetGrouped)
    }
}

// MARK: - Peeviews

#Preview("Loading") {
    makePreviewVaultRecoveryiCloudVaultSelectionView(state: .loading)
}

#Preview("Error") {
    makePreviewVaultRecoveryiCloudVaultSelectionView(state: .error)
}

#Preview("Empty") {
    makePreviewVaultRecoveryiCloudVaultSelectionView(state: .empty)
}

#Preview("List") {
    makePreviewVaultRecoveryiCloudVaultSelectionView(state: .list)
}
    
private func makePreviewVaultRecoveryiCloudVaultSelectionView(state: VaultRecoveryiCloudVaultSelectionModuleInteractorPreview.State) -> some View {
    Color.white
        .sheet(isPresented: .constant(true)) {
            NavigationStack {
                VaultRecoveryiCloudVaultSelectionView(presenter: .init(
                    interactor: VaultRecoveryiCloudVaultSelectionModuleInteractorPreview(state: state),
                    onSelect: { _ in }
                ))
            }
        }
}
