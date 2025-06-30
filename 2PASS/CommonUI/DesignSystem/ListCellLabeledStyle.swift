// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

extension LabeledContentStyle where Self == ListCellLabeledStyle {
    public static var listCell: ListCellLabeledStyle { .init(lineLimit: 2) }
    
    public static func listCell(lineLimit: Int?) -> ListCellLabeledStyle {
        .init(lineLimit: lineLimit)
    }
    
}

public struct ListCellLabeledStyle: LabeledContentStyle {
    
    let lineLimit: Int?
    
    init(lineLimit: Int?) {
        self.lineLimit = lineLimit
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.label
                .foregroundStyle(.base1000)
            
            Spacer()
            
            configuration.content
                .lineLimit(lineLimit)
                .foregroundStyle(.neutral950)
                .multilineTextAlignment(.trailing)
        }
        .font(.body)
    }
}
