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
    
    @State
    private var editMode: EditMode = .inactive
    
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
            
            if presenter.state.hasVaults {
                ToolbarItem(placement: .primaryAction) {
                    switch editMode {
                    case .inactive:
                        Button(T.commonEdit.localizedKey) {
                            withAnimation {
                                editMode = .active
                            }
                        }
                    case .active:
                        Button(T.commonDone.localizedKey) {
                            withAnimation {
                                editMode = .inactive
                            }
                        }
                    default:
                        EmptyView()
                    }
                }
            }
        }
        .onAppear {
            presenter.onAppear()
        }
        .router(router: VaultRecoveryiCloudVaultSelectionRouter(), destination: $presenter.destination)
    }
        
    @ViewBuilder
    private func list(for vaults: [VaultRecoveryiCloudVaultSelectionEntry]) -> some View {
        List {
            VaultListContentView(vaults: vaults, presenter: presenter)
        }
        .environment(\.editMode, $editMode)
        .listSectionSpacing(Spacing.s)
        .listStyle(.insetGrouped)
    }
}

private struct VaultListContentView: View {
    
    let vaults: [VaultRecoveryiCloudVaultSelectionEntry]
    
    let presenter: VaultRecoveryiCloudVaultSelectionPresenter
    
    @Environment(\.editMode)
    private var editMode
    
    @State
    private var showDeleteConfirmation = false
    
    var body: some View {
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
                .disabled(!vault.canBeUsed || editMode?.wrappedValue.isEditing == true)
                .swipeActions(edge: .trailing) {
                    Button {
                        presenter.onDelete(at: index)
                    } label: {
                        Label(T.knownBrowserDeleteButton.localizedKey, systemImage: "trash")
                    }
                    .tint(.danger500)
                }
                
            } header: {
                if index == 0 {
                    Text(T.restoreCloudFilesHeader.localizedKey)
                        .padding(.top, Spacing.s)
                }
            }
        }
        .onDelete { indicies in
            if let index = indicies.first {
                presenter.onDelete(at: index)
            }
        }
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
