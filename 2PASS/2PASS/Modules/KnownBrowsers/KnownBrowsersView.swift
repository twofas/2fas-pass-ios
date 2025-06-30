// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct KnownBrowsersView: View {
    
    @State
    var presenter: KnownBrowsersPresenter
    
    @Environment(\.colorScheme)
    private var colorScheme
    
    var body: some View {
        SettingsDetailsForm(T.knownBrowsersTitle.localizedKey) {
            if presenter.isEmptyList == false {
                Section {
                    ForEach(presenter.browsers) { browser in
                        KnownBrowsersCell(data: browser, identicon: presenter.identicon(for: browser))
                            .swipeActions(edge: .trailing) {
                                Button {
                                    presenter.onDelete(browser)
                                } label: {
                                    Label(T.knownBrowserDeleteButton.localizedKey, systemImage: "trash")
                                }
                                .tint(.danger500)
                            }
                    }
                } header: {
                    Text(T.knownBrowsersHeader.localizedKey)
                } footer: {
                    Text(T.knownBrowsersDescription.localizedKey)
                        .settingsFooter()
                }
                .listRowInsets(EdgeInsets(Spacing.s))
            }
        }
        .overlay {
            if presenter.isEmptyList {
                EmptyListView(T.knownBrowsersEmpty.localizedKey)
            }
        }
        .animation(.default, value: presenter.browsers.count)
        .onAppear {
            presenter.onAppear(colorScheme: colorScheme)
        }
        .router(router: KnownBrowsersRouter(), destination: $presenter.destination)
    }
}

#Preview {
    NavigationStack {
        KnownBrowsersRouter.buildView()
    }
}
