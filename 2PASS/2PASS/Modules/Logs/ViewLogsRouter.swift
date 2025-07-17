// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common
import CommonUI

struct ViewLogsRouter: Router {
    
    static func buildView() -> some View {
        NavigationStack {
            ViewLogsView(presenter: .init(interactor: ModuleInteractorFactory.shared.viewLogsModuleInteractor()))
        }
    }
    
    func view(for destination: ViewLogsDestination) -> some View {
        switch destination {
        case .shareFile(let url, let onComplete, let onError):
            ShareSheetView(title: "Share logs", url: url, activityComplete: onComplete, activityError: onError)
        }
    }
    
    func routingType(for destination: ViewLogsDestination?) -> RoutingType? {
        switch destination {
        case .shareFile:
            return .sheet
        default:
            return nil
        }
    }
}
