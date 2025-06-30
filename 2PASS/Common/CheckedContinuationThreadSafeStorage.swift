// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

public actor CheckedContinuationThreadSafeStorage<T> {
    
    private var continuation: CheckedContinuation<T, Error>?
    private var isCancelled = false
    
    public init() {}
    
    public func set(_ continuation: CheckedContinuation<T, Error>) {
        if isCancelled {
            continuation.resume(throwing: CancellationError())
        } else {
            self.continuation = continuation
        }
    }
    
    public func finish(returning value: T) {
        continuation?.resume(returning: value)
        continuation = nil
    }
    
    public func finish(throwing error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
    
    public func cancel() {
        isCancelled = true
        
        continuation?.resume(throwing: CancellationError())
        continuation = nil
    }
}

extension CheckedContinuationThreadSafeStorage where T == Void {
    
    public func finish() {
        finish(returning: ())
    }
}
