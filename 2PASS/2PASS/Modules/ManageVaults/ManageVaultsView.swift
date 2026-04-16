// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common

struct ManageVaultsView: View {
    @State var presenter: ManageVaultsPresenter

    var body: some View {
        SettingsDetailsForm(Text(.manageVaultsTitle)) {
            Section {
                ForEach(presenter.vaults) { vault in
                    vaultRow(vault)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if !vault.isDefault {
                                Button(role: .destructive) {
                                    presenter.onDeleteVault(vault)
                                } label: {
                                    Label(String(localized: .commonDelete), systemImage: "trash")
                                }
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                presenter.onEditVault(vault)
                            } label: {
                                Label(String(localized: .commonEdit), systemImage: "pencil")
                            }
                            .tint(.accentColor)
                        }
                }
            }

            Section {
                Button {
                    presenter.onAddVault()
                } label: {
                    SettingsRowView(
                        icon: .invite,
                        title: .manageVaultsAddVault
                    )
                    .titleButtonStyle()
                }
            }
        } header: {
            SettingsHeaderView(
                icon: .vaults,
                title: Text(.manageVaultsHeaderTitle),
                description: Text(.manageVaultsCount(presenter.vaults.count))
            )
            .settingsIconStyle(.border)
        }
        .onAppear {
            presenter.onAppear()
        }
        .sheet(isPresented: $presenter.isShowingVaultEditor) {
            VaultEditorSheet(presenter: presenter)
        }
        .alert(
            Text(.manageVaultsDeleteTitle),
            isPresented: $presenter.isShowingDeleteConfirmation
        ) {
            Button(String(localized: .commonCancel), role: .cancel) {}
            Button(String(localized: .commonDelete), role: .destructive) {
                presenter.onConfirmDeleteVault()
            }
        } message: {
            if let vault = presenter.vaultToDelete {
                Text(.manageVaultsDeleteMessage(vault.name, vault.itemCount))
            }
        }
    }

    private func vaultRow(_ vault: VaultViewModel) -> some View {
        HStack(spacing: Spacing.s) {
            Circle()
                .fill(Color(UIColor(vault.color)))
                .frame(
                    width: ItemTagColorMetrics.regular.size,
                    height: ItemTagColorMetrics.regular.size
                )

            if let icon = vault.icon {
                Text(icon)
                    .font(.body)
            }

            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(vault.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(.manageVaultsItemCount(vault.itemCount))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: - Vault Editor Sheet

private struct VaultEditorSheet: View {
    @Bindable var presenter: ManageVaultsPresenter

    @FocusState private var isNameFocused: Bool
    @State private var didFocus = false

    @Environment(\.dismiss) private var dismiss

    private var isPad: Bool { UIDevice.isiPad }

    private var sheetHeight: CGFloat { isPad ? 420 : 380 }

    var body: some View {
        VStack(spacing: Spacing.xll3) {
            Text(presenter.isEditing
                ? .manageVaultsEditVaultTitle
                : .manageVaultsNewVaultTitle
            )
            .font(.title1Emphasized)
            .foregroundStyle(.neutral950)

            VStack(spacing: Spacing.l) {
                nameField

                iconField

                colorPicker
            }

            Button {
                presenter.onConfirmVaultEditor()
            } label: {
                Text(.commonSave)
            }
            .disabled(presenter.editorVaultName
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.horizontal, Spacing.l)
            .buttonStyle(.filled)
            .controlSize(.large)
        }
        .padding(.top, Spacing.xxl4)
        .padding(.bottom, Spacing.l)
        .overlay(alignment: .topTrailing) {
            CloseButton { dismiss() }
                .padding(Spacing.l)
        }
        .presentationDetents([.height(sheetHeight)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.base0)
    }

    private var nameField: some View {
        HStack(spacing: Spacing.s) {
            TextField(
                String(localized: .manageVaultsNamePlaceholder),
                text: $presenter.editorVaultName
            )
            .focused($isNameFocused)
            .onAppear {
                guard !didFocus else { return }
                didFocus = true
                Task { @MainActor in
                    isNameFocused = true
                }
            }
            .onSubmit {
                presenter.onConfirmVaultEditor()
            }

            Circle()
                .fill(Color(UIColor(presenter.editorVaultColor)))
                .frame(
                    width: ItemTagColorMetrics.regular.size,
                    height: ItemTagColorMetrics.regular.size
                )
        }
        .padding(.horizontal, Spacing.l)
        .frame(height: 44)
        .background(Color.neutral50)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, Spacing.l)
    }

    private var iconField: some View {
        HStack(spacing: Spacing.s) {
            Text(.manageVaultsIconLabel)
                .foregroundStyle(.neutral600)

            TextField(
                String(localized: .manageVaultsIconPlaceholder),
                text: $presenter.editorVaultIcon
            )
            .onChange(of: presenter.editorVaultIcon) { _, newValue in
                if newValue.count > 1 {
                    presenter.editorVaultIcon = String(newValue.prefix(1))
                }
            }
            .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, Spacing.l)
        .frame(height: 44)
        .background(Color.neutral50)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, Spacing.l)
    }

    private var colorPicker: some View {
        HStack {
            ForEach(VaultColor.allKnownCases, id: \.self) { color in
                let vaultColor = Color(UIColor(color))
                Button {
                    presenter.editorVaultColor = color
                } label: {
                    Circle()
                        .fill(vaultColor)
                        .frame(
                            width: ItemTagColorMetrics.large.size,
                            height: ItemTagColorMetrics.large.size
                        )
                        .padding(4)
                        .overlay {
                            if presenter.editorVaultColor == color {
                                Circle()
                                    .stroke(vaultColor, lineWidth: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, Spacing.l)
    }
}
