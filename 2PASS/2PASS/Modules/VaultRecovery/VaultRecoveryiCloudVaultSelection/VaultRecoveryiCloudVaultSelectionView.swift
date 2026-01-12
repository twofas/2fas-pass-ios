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
                    title: Text(.restoreIcloudFilesError),
                    description: Text(string),
                    action: {
                        Button(.commonTryAgain) {
                            presenter.retry()
                        }
                    }
                )
                
            case .list(let vaults):
                list(for: vaults)
            case .empty:
                EmptyListView(.restoreCloudFilesEmptyDescription)
            }
        }
        .animation(.easeInOut(duration: 0.1), value: presenter.state)
        .navigationTitle(.restoreIcloudFilesTitle)
        .navigationBarTitleDisplayMode(.inline)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(UIColor.systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                ToolbarCancelButton {
                    dismiss()
                }
            }
            
            if presenter.state.hasVaults {
                ToolbarItem(placement: .primaryAction) {
                    switch editMode {
                    case .inactive:
                        Button(.commonEdit) {
                            withAnimation {
                                editMode = .active
                            }
                        }
                    case .active:
                        Button(.commonDone) {
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
                        Label(.knownBrowserDeleteButton, systemImage: "trash")
                    }
                    .tint(.danger500)
                }
                
            } header: {
                if index == 0 {
                    Text(.restoreCloudFilesHeader)
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
