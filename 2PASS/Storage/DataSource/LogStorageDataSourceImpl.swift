// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import CoreData

public final class LogStorageDataSourceImpl {
    private let coreDataStack: CoreDataStack
    private var handler: LogHandler?
    
    public var storageError: ((String) -> Void)?
    
    var context: NSManagedObjectContext {
        coreDataStack.context
    }
    
    public init() {
        self.coreDataStack = CoreDataStack(
            readOnly: false,
            name: "LogStorage",
            bundle: Bundle(for: LogStorageDataSourceImpl.self),
            storeInGroup: true,	
            isPersistent: true
        )
        
        coreDataStack.logError = { Log($0, module: .storage) }
        coreDataStack.presentErrorToUser = { [weak self] in self?.storageError?($0) }
    }
    
    public func loadStore(completion: @escaping Callback) {
        coreDataStack.loadStore { [weak self] in
            guard let self else { return }
            handler = LogHandler(coreDataStack: coreDataStack)
            completion()
        }
    }
}

extension LogStorageDataSourceImpl: LogStorageDataSource {
    public func store(content: String, timestamp: Date, module: Int, severity: Int) {
        handler?.store(content: content, timestamp: timestamp, module: module, severity: severity)
    }
    
    public func markZoneStart() {
        handler?.markZoneStart()
    }
    
    public func markZoneEnd() {
        handler?.markZoneEnd()
    }
    
    public func listAll() -> [LogEntry] {
        handler?.listAll() ?? []
    }
    
    public func removeAll() {
        handler?.removeAll()
    }
    
    public func save() {
        handler?.save()
    }
    
    public func removeOldStoreLogs() {
        do {
            try CoreDataStack.removeStore(name: "LogStorage")
        } catch {
            Log("Failed to remove old store logs: \(error)", module: .storage, severity: .error)
        }
    }
}
