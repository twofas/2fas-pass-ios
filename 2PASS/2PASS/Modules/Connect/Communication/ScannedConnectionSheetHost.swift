// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Data
import Common

private enum Constants {
    static let dismissAnimationDuration: Duration = .milliseconds(350)
}

/// Transparent full-screen host that presents the scanned-connection acceptance sheet through a SwiftUI
/// `.sheet`, so the sheet adopts SwiftUI's layout-reactive sizing (a fitted card in the split layout, a
/// content bottom sheet in the tab-bar layout) and re-sizes cleanly when the window is resized — unlike a
/// hosting controller presented directly, whose form-sheet sizing stays oversized in a compact width.
///
/// Presented over the iPad split after the Connect scanner is dismissed. `onScanAgain` marks that the user
/// asked to rescan (the sheet dismisses itself first); `onDismiss` fires once the sheet is gone so the host
/// can be torn down.
struct ScannedConnectionSheetHost: View {

    let session: ConnectSession
    let onScanAgain: Callback
    let onDismiss: Callback

    @State
    private var isPresented = false

    var body: some View {
        // Measure the window width at the full-screen host root (the sheet's own content can't be trusted
        // for it — an iPad page sheet is ~704pt wide and reports `.compact`). Drive the sheet's sizing off
        // the Main screen's split/tab layout rather than the size class, so it matches the actual layout in
        // the in-between widths where they diverge (e.g. 11" iPad portrait is `.regular` but tab-bar).
        GeometryReader { proxy in
            Color.clear
                .onAppear {
                    isPresented = true
                }
                .sheet(isPresented: $isPresented) {
                    ConnectCommunicationRouter.buildView(session: session, onScanAgain: onScanAgain)
                        .environment(\.prefersDefaultSheetSize, MainLayout.usesSplitLayout(atWidth: proxy.size.width))
                }
                .onChange(of: isPresented) { _, newValue in
                    guard newValue == false else { return }
                    Task {
                        try await Task.sleep(for: Constants.dismissAnimationDuration)
                        onDismiss()
                    }
                }
        }
    }
}
