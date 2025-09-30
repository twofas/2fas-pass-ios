// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData

public final class CoreDataStack {
    private let migrator: CoreDataMigratorProtocol?
    
    public var logError: ((LogMessage) -> Void)?
    public var initilizingNewStore: (() -> Void)?
    public var presentErrorToUser: ((String) -> Void)?
    
    private let readOnly: Bool
    private let name: String
    private let bundle: Bundle
    private let storeInGroup: Bool
    private let isPersistent: Bool
    private let persistentContainer: NSPersistentContainer
    
    private enum LoadState {
        case initial
        case loading
        case loaded
    }
    
    private var loadState: LoadState = .initial
    private var loadStoreCompletions: [Callback] = []

    public init(
        readOnly: Bool,
        name: String,
        bundle: Bundle,
        storeInGroup: Bool = false,
        migrator: CoreDataMigratorProtocol? = nil,
        isPersistent: Bool = true
    ) {
        self.name = name
        self.bundle = bundle
        self.readOnly = readOnly
        self.storeInGroup = storeInGroup
        self.migrator = migrator
        migrator?.bundle = bundle
        self.isPersistent = isPersistent
        
        self.persistentContainer = NSPersistentContainer(name: name, bundle: bundle)
    }
    
    public func loadStore(completion: @escaping Callback) {
        guard loadState != .loaded else {
            completion()
            return
        }
        configurePersistentContainer(persistentContainer, completion: completion)
    }
    
    private func configurePersistentContainer(_ container: NSPersistentContainer, completion: @escaping Callback) {
        guard loadState != .loading else {
            loadStoreCompletions.append(completion)
            return
        }
        
        loadState = .loading
        loadStoreCompletions.append(completion)
        
        let name = self.name
        if !FileManager.default.fileExists(atPath: storeUrl.path()) {
            DispatchQueue.main.async {
                self.initilizingNewStore?()
            }
        }
        container.persistentStoreDescriptions = [storeDescription]
        
        migrateStoreIfNeeded {
            container.loadPersistentStores { [weak self] _, error in
                if let error = error as NSError? {
                    // swiftlint:disable line_length
                    let err: LogMessage = "Unresolved error while loadPersistentStores: \(error), \(error.userInfo), for stack: \(name)"
                    // swiftlint:enable line_length
                    self?.logError?(err)
                    self?.parseError(with: error.userInfo)
                    fatalError(err.description)
                } else {
                    container.viewContext.automaticallyMergesChangesFromParent = true
                    DispatchQueue.main.async {
                        self?.loadState = .loaded
                        
                        for completion in self?.loadStoreCompletions ?? [] {
                            completion()
                        }
                        self?.loadStoreCompletions = []
                    }
                }
            }
        }
    }
    
    private lazy var storeDescription: NSPersistentStoreDescription = {
        let description = NSPersistentStoreDescription()
        description.shouldInferMappingModelAutomatically = false
        description.shouldMigrateStoreAutomatically = false
        description.isReadOnly = readOnly
        if isPersistent {
            description.url = storeUrl
            description.type = NSSQLiteStoreType
            description.shouldAddStoreAsynchronously = true
        } else {
            description.url = URL(fileURLWithPath: "/dev/null")
            description.type = NSSQLiteStoreType
            description.shouldAddStoreAsynchronously = false
        }
        
        return description
    }()
    
    private lazy var storeUrl: URL = {
        CoreDataStack.storeUrl(forName: name, storeInGroup: storeInGroup)
    }()
    
    public var context: NSManagedObjectContext { persistentContainer.viewContext }
    
    public func save() {
        let context = persistentContainer.viewContext
        save(onContext: context)
    }
    
    public func performInBackground(_ closure: @escaping (NSManagedObjectContext) -> Void) {
        let context = persistentContainer.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.perform { [weak self] in
            closure(context)
            self?.save(onContext: context)
        }
    }
    
    public func performAndWaitInBackground(_ closure: @escaping (NSManagedObjectContext) -> Void) {
        let context = persistentContainer.newBackgroundContext()
        context.automaticallyMergesChangesFromParent = true
        context.performAndWait { [weak self] in
            closure(context)
            self?.save(onContext: context)
        }
    }
    
    public func createBackgroundContext() -> NSManagedObjectContext {
        persistentContainer.newBackgroundContext()
    }
    
    private func save(onContext context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            let nserror = error as NSError
            // swiftlint:disable line_length
            let err: LogMessage = "Unresolved error while saving data: \(nserror), \(nserror.userInfo), for stack: \(String(describing: name), privacy: .public)"
            // swiftlint:enable line_length
            logError?(err)
            assertionFailure(err.description)
        }
    }
    
    public var migrationRequired: Bool {
        guard let migrator, isPersistent else {
            return false
        }
        guard let storeURL = storeDescription.url else {
            fatalError("persistentContainer was not set up properly")
        }
        return migrator.requiresMigrationToCurrentVersion(at: storeURL)
    }
    
    private func migrateStoreIfNeeded(completion: @escaping () -> Void) {
        guard let migrator, isPersistent else {
            completion()
            return
        }
        guard let storeURL = storeDescription.url else {
            fatalError("persistentContainer was not set up properly")
        }
        
        if migrator.requiresMigrationToCurrentVersion(at: storeURL) {
            migrator.migrateStoreToCurrentVersion(at: storeURL)
        }
        completion()
    }
    
    private func parseError(with dict: [String: Any]) {
        guard let value = dict["NSSQLiteErrorDomain"] as? Int, value == 13 else { return }
        // swiftlint:disable line_length
        presentErrorToUser?("It appears that either you've run out of disk space now or the database was damaged by such event in the past")
        // swiftlint:enable line_length
    }
}

extension CoreDataStack {
    
    public static func removeStore(name: String, storeInGroup: Bool = false) throws {
        let storeURL = storeUrl(forName: name, storeInGroup: storeInGroup)
        
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: storeURL.path()) {
            try fileManager.removeItem(at: storeURL)
        }
        
        let shmURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
        let walURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
        
        if fileManager.fileExists(atPath: shmURL.path) {
            try fileManager.removeItem(at: shmURL)
        }
        
        if fileManager.fileExists(atPath: walURL.path) {
            try fileManager.removeItem(at: walURL)
        }
    }
    
    fileprivate static func storeUrl(forName name: String, storeInGroup: Bool) -> URL {
        if storeInGroup {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Config.suiteName)!
                .appendingPathComponent("\(name).sqlite")
        } else {
            getDocumentsDirectory().appendingPathComponent("\(name).sqlite")
        }
    }
    
    private static func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
}

public extension NSPersistentContainer {
    @nonobjc convenience init(name: String, bundle: Bundle) {
        
        guard let modelURL = bundle.url(forResource: name, withExtension: "momd"),
              let mom = NSManagedObjectModel(contentsOf: modelURL)
        else {
            Log("Unable to located Core Data model", module: .storage)
            fatalError("Unable to located Core Data model")
        }
        
        self.init(name: name, managedObjectModel: mom)
    }
}

public extension NSManagedObject {
    @nonobjc func delete() {
        managedObjectContext?.delete(self)
    }
}
