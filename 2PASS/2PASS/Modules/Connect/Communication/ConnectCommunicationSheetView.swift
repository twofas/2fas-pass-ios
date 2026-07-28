// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common
import Data

private struct Constants {
    static let initialSheetHeight = 380.0
    static let resetPresentationDetentsAfterChangedHeightDelay: Duration = .milliseconds(100)
    
    static let contentMinHeight = 178.0
    static let contentCornerRadius = 16.0

    static let webBrowserInfoMinHeight = 190.0

    /// Ideal width for the iOS 18 `.fitted` sheet so the iPad card isn't squeezed to its intrinsic
    /// content width. iPhone ignores it (the sheet is proposed a concrete full width).
    static let fittedSheetWidth = 420.0
}

struct ConnectCommunicationSheetView<Content>: View where Content: View {

    let title: Text
    let identicon: String?
    let webBrowser: WebBrowser?
    
    let content: Content
    let onClose: Callback?
    
    init(title: Text, identicon: String?, webBrowser: WebBrowser?, onClose: Callback? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.identicon = identicon
        self.webBrowser = webBrowser
        self.onClose = onClose
        self.content = content()
    }
    
    @Environment(\.colorScheme)
    private var colorScheme

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    /// Injected by the presentation site (which has a reliable trait, unlike this sheet's own content —
    /// an iPad page sheet is ~704pt wide and reports a `.compact` size class). When true the sheet keeps
    /// the system's default page-sheet size instead of the iPhone content-hugging height detents.
    @Environment(\.prefersDefaultSheetSize)
    private var prefersDefaultSheetSize

    @State
    private var contentHeight = Constants.initialSheetHeight

    @State
    private var presentationDetent: PresentationDetent = .height(Constants.initialSheetHeight)
    
    @State
    private var presentationDetents: Set<PresentationDetent> = [.height(Constants.initialSheetHeight)]
    
    var body: some View {
        sheetContent
            .onAppear {
                hideKeyboard()
            }
            .presentationDragIndicator(.hidden)
    }

    @ViewBuilder
    private var sheetContent: some View {
        if #available(iOS 18.0, *) {
            // Unified iOS 18 path with a single content layout (intrinsic `sheetBody`, no `GeometryReader`)
            // and `.presentationSizing(.fitted)` mounted in BOTH size classes and from first presentation.
            // Keeping the sizing modifier constant is what makes a live small→large resize re-fit cleanly:
            // only the detents are added/removed (which SwiftUI updates live), instead of swapping the
            // presentation-modifier type on an already-presented sheet (which left it stuck oversized).
            //
            // - regular width (iPad, `prefersDefaultSheetSize`): no detents → `.fitted` gives a content
            //   -sized card (ideal width so it isn't squeezed to its intrinsic content width).
            // - compact width: the system ignores `.fitted`, and the height detent makes it a bottom sheet.
            sheetBody
                .frame(idealWidth: Constants.fittedSheetWidth, maxWidth: .infinity)
                .background((colorScheme == .dark ? Color.neutral100 : Color.neutral50).ignoresSafeArea())
                .onGeometryChange(for: CGFloat.self, of: { $0.size.height }, action: updateDetents)
                .presentationSizing(.fitted)
                .if(!prefersDefaultSheetSize) {
                    $0.presentationDetents(presentationDetents, selection: $presentationDetent)
                }
        } else {
            // iOS 17.4 (no `presentationSizing`): iPhone/compact → content-hugging bottom sheet via height
            // detents; iPad (`prefersDefaultSheetSize`) → the system default page-sheet size (detents
            // skipped). The `GeometryReader` top-aligns the content so the height-change animation reads
            // cleanly, and the content fills the externally detent-sized sheet.
            ZStack(alignment: .top) {
                (colorScheme == .dark ? Color.neutral100 : Color.neutral50)
                    .ignoresSafeArea()

                GeometryReader { _ in // Content align to top. Fix for change sheet height animation.
                    sheetBody
                        .onGeometryChange(for: CGFloat.self, of: { $0.size.height }, action: updateDetents)
                }
            }
            .if(!prefersDefaultSheetSize) {
                $0.presentationDetents(presentationDetents, selection: $presentationDetent)
            }
        }
    }

    /// Tracks the content's measured height and republishes it as the single active detent (used only by
    /// the compact bottom-sheet presentation). Briefly exposes both the old and new heights so the change
    /// animates, then collapses back to a single detent.
    private func updateDetents(measuredHeight height: CGFloat) {
        let oldHeight = contentHeight
        contentHeight = ceil(height)
        guard contentHeight != oldHeight else { return }

        presentationDetents = [.height(oldHeight), .height(contentHeight)]
        presentationDetent = .height(contentHeight)

        Task { @MainActor in
            try await Task.sleep(for: Constants.resetPresentationDetentsAfterChangedHeightDelay)
            presentationDetents = [.height(contentHeight)]
        }
    }

    /// The sheet's intrinsic content: identicon + title header over the content card, with the close
    /// button overlaid. Sizes to its natural height so `.fitted` can measure it; on iOS 17.4 it is
    /// hosted inside a `GeometryReader` and sized by detents instead.
    private var sheetBody: some View {
        VStack(spacing: 0) {
            VStack(spacing: Spacing.xl) {
                ConnectIdenticonView(identicon: identicon)

                VStack(spacing: Spacing.xxs) {
                    title
                        .font(.subheadlineEmphasized)
                        .foregroundStyle(.neutral950)

                    if let webBrowser {
                        Text(webBrowser.extName)
                            .font(.footnote)
                            .foregroundStyle(.neutral600)
                    }
                }
            }
            .animation(reduceMotion ? nil : .default, value: webBrowser != nil)
            .frame(minHeight: Constants.webBrowserInfoMinHeight)

            content
                .padding(Spacing.l)
                .frame(minHeight: Constants.contentMinHeight)
                .frame(maxWidth: .infinity)
                .background(colorScheme == .dark ? .neutral50 : .base0)
                .clipShape(RoundedRectangle(cornerRadius: Constants.contentCornerRadius))
                .padding(.horizontal, Spacing.m)
                .padding(.bottom, Spacing.m)
                .fixedSize(horizontal: false, vertical: true)
        }
        .overlay(alignment: .topTrailing) {
            CloseButton {
                onClose?()
            }
            .padding(Spacing.l)
        }
    }
    
    private func hideKeyboard() {
        UIApplication.shared.hideKeyboard()
    }
}

private struct PrefersDefaultSheetSizeKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {

    /// Set by a presentation site that has a reliable size trait (a full-screen window root, or a flow
    /// controller that knows it presents a form sheet) to tell `ConnectCommunicationSheetView` to use the
    /// system's default page-sheet size instead of the iPhone content-hugging height detents. Defaults to
    /// `false` so the tab-bar / iPhone presentation keeps the bottom-sheet behaviour.
    var prefersDefaultSheetSize: Bool {
        get { self[PrefersDefaultSheetSizeKey.self] }
        set { self[PrefersDefaultSheetSizeKey.self] = newValue }
    }
}
