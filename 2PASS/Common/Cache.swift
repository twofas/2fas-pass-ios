// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit

public final class Cache<Key: Hashable, Value> {
    
    public enum UseSynchronization {
        case yes(queueName: String, asyncWrite: Bool = false)
        case no
    }
    
    private var cache: [Key: Value] = [:]
    private let sync: CacheSynchronization
    
    public init(useSynchronization: UseSynchronization) {
        switch useSynchronization {
        case .yes(let queueName, let asyncWrite):
            sync = QueueSynchronization(queueName: queueName, asyncWrite: asyncWrite)
        case .no:
            sync = NoSynchronization()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(clear),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    public subscript(key: Key) -> Value? {
        get {
            var result: Value?
            sync.read {
                result = self.cache[key]
            }
            return result
        }
        set {
            sync.write {
                self.cache[key] = newValue
            }
        }
    }
    
    public func set(_ value: Value, for key: Key) {
        self[key] = value
    }
    
    public func get(for key: Key) -> Value? {
        self[key]
    }
    
    @objc
    private func clear() {
        sync.write {
            self.cache.removeAll()
        }
    }
}

private protocol CacheSynchronization: AnyObject {
    func read<T>(_ block: () -> T) -> T
    func write(_ block: @escaping () -> Void)
}

private final class QueueSynchronization: CacheSynchronization {
    private let queue: DispatchQueue
    private let asyncWrite: Bool
    
    init(queueName: String, asyncWrite: Bool) {
        self.queue = DispatchQueue(label: queueName, attributes: .concurrent)
        self.asyncWrite = asyncWrite
    }
    
    func read<T>(_ block: () -> T) -> T {
        queue.sync { block() }
    }
    
    func write(_ block: @escaping () -> Void) {
        if asyncWrite {
            queue.async(flags: .barrier) { block() }
        } else {
            queue.sync(flags: .barrier) { block() }
        }
    }
}

private final class NoSynchronization: CacheSynchronization {
    func read<T>(_ block: () -> T) -> T {
        return block()
    }
    
    func write(_ block: @escaping () -> Void) {
        block()
    }
}
