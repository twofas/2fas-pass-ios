// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common

struct TrashView: View {
    
    @State
    var presenter: TrashPresenter
    
    var body: some View {
        List {
            ForEach(presenter.items, id: \.self) { item in
                TrashCell(data: item, presenter: presenter)
                    .onAppear {
                        presenter.onAppear(for: item)
                    }
                    .onDisappear {
                        presenter.onDisappear(for: item)
                    }
                    .listRowInsets(EdgeInsets(
                        top: Spacing.m,
                        leading: Spacing.m,
                        bottom: Spacing.m,
                        trailing: Spacing.l
                    ))
                    .listRowBackground(Color(UIColor.systemGroupedBackground))
            }
        }
        .overlay {
            if presenter.isTrashEmpty {
                EmptyListView(.trashEmpty)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .contentMargins(.vertical, Spacing.l)
        .listStyle(.plain)
        .listRowSeparator(.visible)
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(.settingsEntryTrash)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onAppear()
        }
        .onDisappear {
            presenter.onDisappear()
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if presenter.isTrashEmpty == false {
                    bulkActionsMenu
                }
            }
        }
        .router(router: TrashRouter(), destination: $presenter.destination)
    }

    private var bulkActionsMenu: some View {
        Menu {
            Button {
                presenter.onRestoreAll()
            } label: {
                HStack {
                    Image(systemName: "arrow.2.squarepath")
                    Text(.trashRestoreAll)
                }
            }

            Button(role: ButtonRole.destructive) {
                presenter.onRemoveAll()
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text(.trashRemoveAll)
                }
            }
        } label: {
            Image(systemName: "ellipsis")
        }
    }
}

#Preview {
    TrashView(presenter: .init(interactor: PreviewTrashModuleInteractor()))
}
