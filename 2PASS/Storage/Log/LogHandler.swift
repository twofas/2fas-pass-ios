// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import UIKit
import CoreData
import Common

final class LogHandler: LogStorageHandling {
    private struct CachedEntry {
        let content: String
        let timestamp: Date
        let module: Int
        let severity: Int
    }
    
    private let maxEntries: Int = 10000
    private let checkEvery: Int = 300
    private let saveEvery: Int = 10
    private var checkCounter: Int = 0
    private var saveCounter: Int = 0
    private var zoneSaveCounter: Int = 0
        
    private var inZone = false
    
    private let context: NSManagedObjectContext
    private let queue = DispatchQueue(
        label: "com.2pass.logHandlerQueue",
        attributes: .concurrent
    )
    
    init(coreDataStack: CoreDataStack) {
        context = coreDataStack.createBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(save),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(save),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(save),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    func markZoneStart() {
        inZone = true
    }
    
    func markZoneEnd() {
        inZone = false
        saveCounter += zoneSaveCounter
        zoneSaveCounter = 0
        checkSave()
    }
    
    func store(content: String, timestamp: Date, module: Int, severity: Int) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            self.context.performAndWait {
                LogEntryEntity.create(
                    on: self.context,
                    content: content,
                    timestamp: timestamp,
                    module: module,
                    severity: severity
                )
            }
            
            self.checkCounter += 1
            
            if self.inZone {
                self.zoneSaveCounter += 1
            } else {
                self.saveCounter += 1
                self.checkSave()
                self.checkCleanup()
            }
        }
    }
    
    func removeAll() {
        queue.sync {
            LogEntryEntity.removeAll(on: context)
        }
    }
    
    func listAll() -> [LogEntry] {
        queue.sync {
            LogEntryEntity.listAll(on: context, ascending: false)
                .map { entity in
                    LogEntry(
                        content: entity.content,
                        timestamp: entity.timestamp,
                        module: LogModule(rawValue: Int(entity.module)) ?? .unknown,
                        severity: LogSeverity(rawValue: Int(entity.severity)) ?? .unknown
                    )
                }
        }
    }
    
    private func checkSave() {
        guard saveCounter >= saveEvery else { return }
        
        save()
    }
    
    @objc(save)
    private func save() {
        queue.async(flags: .barrier) { [weak self] in
            self?.saveCounter = 0
            self?.zoneSaveCounter = 0
            
            self?.context.performAndWait { [weak self] in
                if self?.context.hasChanges == true {
                    do {
                        try self?.context.save()
                    } catch {
                        Log("Error while saving context in LogStorage: \(error)")
                    }
                }
            }
        }
    }
    
    private func checkCleanup() {
        guard checkCounter >= checkEvery else { return }
        checkCounter = 0
        
        queue.async(flags: .barrier) { [weak self] in
            self?.context.performAndWait { [weak self] in
                guard let self else { return }
                let context = self.context
                
                guard LogEntryEntity.count(on: context) > self.maxEntries else { return }
                let all = LogEntryEntity.listAll(on: context, quickFetch: true, ascending: false)
                let forRemoval = Array(all[self.maxEntries...])
                LogEntryEntity.remove(on: context, objects: forRemoval)
            }
        }
    }
}
