// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation

/// Generic debouncer for QR code scanning.
/// Waits 300ms after code detection/loss to avoid rapid state changes.
public final class ScanDebouncer {
    private var pendingTask: Task<Void, Never>?
    private var pendingCode: String?
    private let delay: Duration

    public init(delay: Duration = .milliseconds(300)) {
        self.delay = delay
    }

    /// Schedules processing of a detected code with debounce.
    /// - Parameters:
    ///   - code: The raw code string
    ///   - task: Closure called after debounce delay
    @MainActor
    public func scheduleDetected(
        code: String,
        task: @escaping (String) -> Void
    ) {
        guard pendingCode != code else { return }
        pendingCode = code
        cancelPendingTask()
        pendingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.delay)
            guard self.pendingCode == code else { return }
            task(code)
        }
    }

    /// Schedules processing when a code is lost from view with debounce.
    /// - Parameter onLost: Called when the code has been lost for the debounce duration
    @MainActor
    public func scheduleLost(onLost: @escaping () -> Void) {
        guard pendingCode != nil else { return }
        pendingCode = nil
        cancelPendingTask()
        pendingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: self.delay)
            guard self.pendingCode == nil else { return }
            onLost()
        }
    }

    /// Resets the debouncer state.
    /// Call this when the view appears or when navigation occurs.
    @MainActor
    public func reset() {
        pendingCode = nil
        cancelPendingTask()
    }

    @MainActor
    private func cancelPendingTask() {
        pendingTask?.cancel()
        pendingTask = nil
    }
}
