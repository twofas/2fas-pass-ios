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
            ForEach(presenter.passwords, id: \.self) { password in
                TrashCell(data: password, presenter: presenter)
                    .onAppear {
                        presenter.onAppear(for: password)
                    }
                    .onDisappear {
                        presenter.onDisappear(for: password)
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
                EmptyListView(T.trashEmpty.localizedKey)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .contentMargins(.vertical, Spacing.l)
        .listStyle(.plain)
        .listRowSeparator(.visible)
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(T.settingsEntryTrash.localizedKey)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            presenter.onAppear()
        }
        .router(router: TrashRouter(), destination: $presenter.destination)
    }
}

#Preview {
    TrashView(presenter: .init(interactor: PreviewTrashModuleInteractor()))
}
