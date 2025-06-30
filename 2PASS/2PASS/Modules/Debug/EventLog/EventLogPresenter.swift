// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import Common

@Observable
final class EventLogPresenter {
    struct Event: Identifiable, Hashable {
        let id: UUID
        let date: String
        let icons: String
        let text: String
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
    var logs: [Event] = []
    
    private let interactor: EventLogModuleInteracting
    
    init(interactor: EventLogModuleInteracting) {
        self.interactor = interactor
    }
}

extension EventLogPresenter {
    func onAppear() {
        reload()
    }
    
    func onRefresh() {
        reload()
    }
    
    func onCopy() {
        UIPasteboard.general.string = self.logs[0..<250].map({ "\($0.date) | \($0.icons) | \($0.text)" })
            .joined(separator: "\n")
    }
}

private extension EventLogPresenter {
    func reload() {
        DispatchQueue.global(qos: .userInitiated).async {
            let list = self.interactor.listAll()
            let transformed: [Event] = list.map { entry in
                let parts = LogPrinter.formatParts(
                    content: entry.content,
                    timestamp: entry.timestamp,
                    module: entry.module,
                    severity: entry.severity
                )
                return Event(
                    id: .init(),
                    date: parts.date,
                    icons: parts.icons,
                    text: parts.content
                )
            }
            DispatchQueue.main.async {
                self.logs = transformed
            }
        }
    }
}
