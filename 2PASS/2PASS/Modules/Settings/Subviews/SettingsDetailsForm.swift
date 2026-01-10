// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

struct SettingsDetailsForm<Content, Header>: View where Content: View, Header: View {
    
    let title: Text
    private let content: Content
    private let header: Header

    private var navigationBarTitleVisibility: Visibility = .automatic
    @State private var hideNavigationBarTitle: Bool = true
    
    init(_ title: Text, @ViewBuilder content: () -> Content, @ViewBuilder header: () -> Header) {
        self.title = title
        self.content = content()
        self.header = header()
    }
    
    init(_ title: LocalizedStringResource, @ViewBuilder content: () -> Content, @ViewBuilder header: () -> Header) {
        self.title = Text(title)
        self.content = content()
        self.header = header()
    }
    
    func navigationBarTitleVisibility(_ visibility: Visibility) -> Self {
        var instance = self
        instance.navigationBarTitleVisibility = visibility
        return instance
    }
    
    var body: some View {
        Form {
            Section {
                header
                    .listRowInsets(EdgeInsets())
            }
            
            content
        }
        .contentMargins(.top, hasHeader ? Spacing.l : nil)
        .scrollBounceBehavior(.basedOnSize)
        .toolbarTitleDisplayMode(.inline)
        .navigationTitle(navigationTitle)
        .onPreferenceChange(SettingsFormTopBarTitleHiddenPreferenceKey.self) { hidden in
            hideNavigationBarTitle = hidden ?? false
        }
    }
    
    private var hasHeader: Bool {
        header is EmptyView == false
    }
    
    private var navigationTitle: Text {
        switch navigationBarTitleVisibility {
        case .automatic:
            return hasHeader && hideNavigationBarTitle ? Text(verbatim: "") : title
        case .visible:
            return title
        case .hidden:
            return Text(verbatim: "")
        }
    }
}

extension SettingsDetailsForm where Header == EmptyView {
    
    init(_ title: Text, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
        self.header = EmptyView()
    }
    
    init(_ title: LocalizedStringResource, @ViewBuilder content: () -> Content) {
        self.title = Text(title)
        self.content = content()
        self.header = EmptyView()
    }
}

extension View {
    
    func settingsFormNavigationBarTitleHidden(_ hidden: Bool) -> some View {
        preference(key: SettingsFormTopBarTitleHiddenPreferenceKey.self, value: hidden)
    }
}

private struct SettingsFormTopBarTitleHiddenPreferenceKey: PreferenceKey {
    static let defaultValue: Bool? = nil
    
    static func reduce(value: inout Bool?, nextValue: () -> Bool?) {
        value = nextValue() ?? value
    }
}
