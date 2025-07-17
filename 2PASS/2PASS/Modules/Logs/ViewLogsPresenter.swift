// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import CommonUI

enum ViewLogsDestination: RouterDestination {
    case shareFile(URL, onComplete: Callback, onError: Callback)
    
    var id: String {
        switch self {
        case .shareFile: "shareFile"
        }
    }
}

@Observable
final class ViewLogsPresenter {
    struct Event: Identifiable, Hashable {
        let id: UUID
        let date: String
        let icons: String
        let text: String
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
    }
    
    var destination: ViewLogsDestination?
    private(set) var logs: [Event] = []
    
    private var loadTask: Task<Void, Never>?
    private var generateTask: Task<Void, Never>?
    
    private let interactor: ViewLogsModuleInteracting
    
    init(interactor: ViewLogsModuleInteracting) {
        self.interactor = interactor
    }
}

extension ViewLogsPresenter {
    
    func onAppear() {
        reload()
    }
    
    func onDisappear() {
        loadTask?.cancel()
        loadTask = nil
        generateTask?.cancel()
        generateTask = nil
    }
    
    func onShare() {
        generateTask?.cancel()
        generateTask = Task { @MainActor in
            guard let url = try? await interactor.generateFile() else {
                return
            }
         
            guard Task.isCancelled == false else {
                return
            }
        
            destination = .shareFile(url, onComplete: {}, onError: {})
        }
    }
}

private extension ViewLogsPresenter {
    
    func reload() {
        loadTask = Task	 {
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
            
            Task { @MainActor in
                self.logs = transformed
            }
        }
    }
}
