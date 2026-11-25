// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

/// Shared by several mocks of one test to assert the order of calls across them.
/// Entries are `"<MockType>.<function>"`, e.g. `"MockStorageInteractor.initialize(completion:)"`.
final class MockCallLog {
    private(set) var calls: [String] = []

    func record(_ call: String) {
        calls.append(call)
    }
}

/// Call tracking of an interactor mock. Functions are recorded, property reads are not.
protocol CallTrackingMock: AnyObject {
    var methodCalls: [String] { get set }
    var callLog: MockCallLog? { get }
}

extension CallTrackingMock {

    func recordCall(_ name: String = #function) {
        methodCalls.append(name)
        callLog?.record("\(Self.self).\(name)")
    }

    func resetCalls() {
        methodCalls.removeAll()
    }

    func wasCalled(_ method: String) -> Bool {
        methodCalls.contains(method)
    }

    func callCount(_ method: String) -> Int {
        methodCalls.filter { $0 == method }.count
    }
}
