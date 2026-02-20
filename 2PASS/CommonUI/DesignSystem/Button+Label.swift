// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

extension LabelStyle where Self == ButtonLabelStyle {
    static var button: ButtonLabelStyle {
        .init()
    }
}

extension Button where Label == SwiftUI.Label<Text, SymbolButtonLabel> {
    
    public init(_ text: Text, symbol: Image, action: @MainActor @escaping () -> Void) {
        self.init(action: action, label: {
            SwiftUI.Label(title: { text }, icon: { SymbolButtonLabel(symbol: symbol) })
        })
    }
    
    @_disfavoredOverload
    public init<S>(_ text: S, symbol: Image, action: @MainActor @escaping () -> Void) where S: StringProtocol {
        self.init(Text(text), symbol: symbol, action: action)
    }
    
    public init(_ text: LocalizedStringKey, symbol: Image, action: @MainActor @escaping () -> Void) {
        self.init(Text(text), symbol: symbol, action: action)
    }
}

extension Button where Label == SymbolButtonLabel {
    
    public init(symbol: Image, action: @MainActor @escaping () -> Void) {
        self.init(action: action, label: {
            SymbolButtonLabel(symbol: symbol)
        })
    }
}

public struct SymbolButtonLabel: View {
    private let symbol: Image
    
    public init(symbol: Image) {
        self.symbol = symbol
    }
        
    public var body: some View {
        symbol
    }
}

struct ButtonLabelStyle: LabelStyle {
    
    @ViewBuilder
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon
            configuration.title
        }
    }
}
