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
    
    @State
    private var contentHeight = Constants.initialSheetHeight

    @State
    private var presentationDetent: PresentationDetent = .height(Constants.initialSheetHeight)
    
    @State
    private var presentationDetents: Set<PresentationDetent> = [.height(Constants.initialSheetHeight)]
    
    var body: some View {
        ZStack(alignment: .top) {
            (colorScheme == .dark ? Color.neutral100 : Color.neutral50)
                .ignoresSafeArea()
            
            GeometryReader { _ in // Content align to top. Fix for change sheet height aniamtion.
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
                    .animation(.default, value: webBrowser != nil)
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
                .onGeometryChange(for: CGFloat.self, of: { proxy in
                    proxy.size.height
                }, action: { height in
                    let oldHeight = contentHeight
                    contentHeight = ceil(height)
                    
                    if contentHeight != oldHeight {
                        presentationDetents = [.height(oldHeight), .height(contentHeight)]
                        presentationDetent = .height(contentHeight)

                        Task { @MainActor in
                            try await Task.sleep(for: Constants.resetPresentationDetentsAfterChangedHeightDelay)
                            presentationDetents = [.height(contentHeight)]
                        }
                    }
                })
                .overlay(alignment: .topTrailing) {
                    CloseButton {
                        onClose?()
                    }
                    .padding(Spacing.l)
                }
            }
        }
        .onAppear {
            hideKeyboard()
        }
        .presentationDetents(presentationDetents, selection: $presentationDetent)
        .presentationDragIndicator(.hidden)
    }
    
    private func hideKeyboard() {
        UIApplication.shared.hideKeyboard()
    }
}
