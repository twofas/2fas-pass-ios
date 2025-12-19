// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public struct RevealToggleStyle: ToggleStyle {

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.$isOn.wrappedValue.toggle()
        } label: {
            Image(systemName: configuration.isOn ? "eye.slash" : "eye")
                .foregroundStyle(Asset.labelSecondaryColor.swiftUIColor)
        }
    }
}

public extension ToggleStyle where Self == RevealToggleStyle {
    static var reveal: RevealToggleStyle { RevealToggleStyle() }
}
