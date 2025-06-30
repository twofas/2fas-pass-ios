// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct DebugStatusView: View {
    @State
    var selectedSegment = 0
    private let segments = ["App State", "Logs"]
    
    let close: () -> Void
    let selectedSegmentEvent: (Int) -> Void

    var body: some View {
        NavigationStack {
            VStack {
                if selectedSegment == 0 {
                    AppStateBuilder.build()
                } else {
                    EventLogBuilder.build()
                }
             }
             .toolbar {
                 ToolbarItem(placement: .principal) {
                     Picker("Debug View" as String, selection: $selectedSegment) {
                         ForEach(0..<segments.count, id: \.self) { index in
                             Text(segments[index]).tag(index)
                         }
                     }
                     .pickerStyle(.segmented)
                 }
                 ToolbarItem(placement: .topBarLeading) {
                     Button {
                         close()
                     } label: {
                         Image(systemName: "xmark")
                     }
                 }
             }
             .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: selectedSegment, { oldValue, newValue in
            selectedSegmentEvent(newValue)
        })
    }
}
