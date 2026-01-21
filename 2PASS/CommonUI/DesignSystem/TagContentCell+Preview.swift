// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

private let content = List {
    Section("With Color" as String) {
        HStack {
            TagContentCell(
                name: Text("Work" as String),
                color: .indigo
            )
        }

        HStack {
            TagContentCell(
                name: Text("Personal" as String),
                color: .green,
                subtitle: Text("5 items" as String)
            )
        }

        HStack {
            TagContentCell(
                name: Text("Important" as String),
                color: .red,
                subtitle: Text("12 items" as String)
            )
        }
    }

    Section("Without Color" as String) {
        HStack {
            TagContentCell(
                name: Text("Untagged" as String),
                color: nil
            )
        }

        HStack {
            TagContentCell(
                name: Text("No Color" as String),
                color: nil,
                subtitle: Text("3 items" as String)
            )
        }
    }

    Section("All Colors" as String) {
        HStack {
            TagContentCell(name: Text("Gray" as String), color: .gray)
        }
        HStack {
            TagContentCell(name: Text("Red" as String), color: .red)
        }
        HStack {
            TagContentCell(name: Text("Orange" as String), color: .orange)
        }
        HStack {
            TagContentCell(name: Text("Yellow" as String), color: .yellow)
        }
        HStack {
            TagContentCell(name: Text("Green" as String), color: .green)
        }
        HStack {
            TagContentCell(name: Text("Cyan" as String), color: .cyan)
        }
        HStack {
            TagContentCell(name: Text("Indigo" as String), color: .indigo)
        }
        HStack {
            TagContentCell(name: Text("Purple" as String), color: .purple)
        }
    }
}

#Preview {
    content
}

#Preview("Sheet") {
    Color.black
        .sheet(isPresented: .constant(true)) {
            content
        }
}
