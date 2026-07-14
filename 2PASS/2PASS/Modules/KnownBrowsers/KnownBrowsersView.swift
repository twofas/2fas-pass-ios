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
        SettingsDetailsForm(.knownBrowsersTitle) {
            if presenter.isEmptyList == false {
                Section {
                    ForEach(presenter.browsers) { browser in
                        KnownBrowsersCell(
                            data: browser,
                            identicon: presenter.identicon(for: browser),
                            onDelete: {
                                presenter.onDelete(browser)
                            }
                        )
                    }
                } header: {
                    Text(.knownBrowsersHeader)
                } footer: {
                    Text(.knownBrowsersDescription)
                        .settingsFooter()
                }
                .listRowInsets(EdgeInsets(top: Spacing.s, leading: Spacing.s, bottom: Spacing.s, trailing: Spacing.l))
            }
        }
        .overlay {
            if presenter.isEmptyList {
                EmptyListView(.knownBrowsersEmpty)
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
