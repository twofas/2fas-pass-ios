// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

struct DismissFlowEnvironemntKey: EnvironmentKey {
    static let defaultValue: DismissFlowAction = .init(action: {})
}

@MainActor
struct DismissFlowAction {
    
    let action: Callback
    
    func callAsFunction() {
        action()
    }
}

extension EnvironmentValues {
    
    var dismissFlow: DismissFlowAction {
        get {
            self[DismissFlowEnvironemntKey.self]
        } set {
            self[DismissFlowEnvironemntKey.self] = newValue
        }
    }
}

struct ResultFlowEnvironemntKey: EnvironmentKey {
    static let defaultValue: ResultFlowAction<Void, Error> = .init(action: { _ in })
}

public struct ResultFlowAction<T, E> where E: Error {
    
    let action: (Result<T, E>) -> Void
    
    public init(action: @escaping (Result<T, E>) -> Void) {
        self.action = action
    }
    
    public func callAsFunction(result: Result<T, E>) {
        action(result)
    }
}

extension EnvironmentValues {
    
    var resultFlow: ResultFlowAction<Void, Error> {
        get {
            self[ResultFlowEnvironemntKey.self]
        } set {
            self[ResultFlowEnvironemntKey.self] = newValue
        }
    }
}

