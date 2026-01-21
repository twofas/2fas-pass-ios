// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct MostUsedUsernamesSheet: View {
    let usernames: [String]
    let onSelect: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack {
                if usernames.isEmpty {
                    Text(.loginUsernameMostUsedEmpty)
                        .font(.subheadline)
                } else {
                    Form {
                        Section {
                            ForEach(usernames, id: \.self) { username in
                                Button {
                                    onSelect(username)
                                } label: {
                                    Text(verbatim: username)
                                        .font(.body)
                                }
                                .foregroundStyle(.primary)
                            }
                        }
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .toolbarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    ToolbarCancelButton {
                        onCancel()
                    }
                }
            }
            .navigationTitle(.loginUsernameMostUsedHeader)
        }
        .presentationDetents([.medium])
    }
}

#Preview("With Usernames") {
    MostUsedUsernamesSheet(
        usernames: [
            "john.doe@example.com",
            "jane.smith@company.org",
            "admin@localhost",
            "user123"
        ],
        onSelect: { username in
            print("Selected: \(username)")
        },
        onCancel: {
            print("Cancelled")
        }
    )
}

#Preview("Empty State") {
    MostUsedUsernamesSheet(
        usernames: [],
        onSelect: { _ in },
        onCancel: {}
    )
}
