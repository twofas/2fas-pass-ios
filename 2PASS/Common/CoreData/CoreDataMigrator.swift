// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData

public protocol CoreDataMigratorProtocol: AnyObject {
    associatedtype Version: CoreDataModelVersionProtocol
    typealias Migrating = ((Version, Version) -> Void)

    func requiresMigrationToCurrentVersion(at storeURL: URL) -> Bool
    func migrateStoreToCurrentVersion(at storeURL: URL, usesPersistentHistoryTracking: Bool) throws
    func pendingDestinationVersions(at storeURL: URL) -> [Version]
    var bundle: Bundle? { get set }
    var migrating: Migrating? { get set }
}
    
public final class CoreDataMigrator<Version: CoreDataModelVersionProtocol>: CoreDataMigratorProtocol {
    public var bundle: Bundle?
    public var migrating: ((Version, Version) -> Void)?
    private let momdSubdirectory: String
    private let versions: CoreDataModelVersionList<Version>

    // MARK: - Init

    public init(momdSubdirectory: String, versions: [Version], migrating: ((Version, Version) -> Void)? = nil) {
        self.momdSubdirectory = "\(momdSubdirectory).momd"
        self.versions = CoreDataModelVersionList(versions: versions)
        self.migrating = migrating
    }

    // MARK: - Check

    public func requiresMigrationToCurrentVersion(at storeURL: URL) -> Bool {
        guard let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL) else {
            return false
        }
        guard let bundle else {
            fatalError("Cant migrate without passed bundle")
        }
        
        let storedVersion = compatibleVersionForStoreMetadata(
            metadata,
            momdSubdirectory: momdSubdirectory,
            bundle: bundle
        )
        let needsToMigrate = (storedVersion?.versionName != versions.current.versionName)
        if needsToMigrate {
            // swiftlint:disable line_length
            Log("Need to migrate Core Data to current version: \(versions.current.versionName, privacy: .public) from \(String(describing: storedVersion?.versionName), privacy: .public)", module: .storage)
            // swiftlint:enable line_length
        }
        
        return needsToMigrate
    }

    // MARK: - Migration

    public func migrateStoreToCurrentVersion(at storeURL: URL, usesPersistentHistoryTracking: Bool) throws {
        forceWALCheckpointingForStore(at: storeURL, usesPersistentHistoryTracking: usesPersistentHistoryTracking)

        var currentURL = storeURL
        let migrationSteps = self.migrationStepsForStore(at: storeURL, toVersion: versions.current)

        for migrationStep in migrationSteps {
            Log("Migrating from \(migrationStep.sourceModel) to \(migrationStep.destinationModel)", module: .storage)
            let manager = NSMigrationManager(
                sourceModel: migrationStep.sourceModel,
                destinationModel: migrationStep.destinationModel
            )
            let destinationURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent(UUID().uuidString)

            var storeOptions: [String: Any] = [:]
            if usesPersistentHistoryTracking {
                storeOptions[NSPersistentHistoryTrackingKey] = true
            }
            try manager.migrateStore(
                from: currentURL,
                sourceType: NSSQLiteStoreType,
                options: storeOptions.isEmpty ? nil : storeOptions,
                with: migrationStep.mappingModel,
                toDestinationURL: destinationURL,
                destinationType: NSSQLiteStoreType,
                destinationOptions: storeOptions.isEmpty ? nil : storeOptions
            )

            if currentURL != storeURL {
                NSPersistentStoreCoordinator.destroyStore(at: currentURL)
            }

            currentURL = destinationURL
        }

        NSPersistentStoreCoordinator.replaceStore(at: storeURL, withStoreAt: currentURL)

        if currentURL != storeURL {
            NSPersistentStoreCoordinator.destroyStore(at: currentURL)
        }
    }

    // MARK: - Pending Versions

    public func pendingDestinationVersions(at storeURL: URL) -> [Version] {
        guard let bundle else { return [] }
        guard let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL),
              let sourceVersion = compatibleVersionForStoreMetadata(
                  metadata,
                  momdSubdirectory: momdSubdirectory,
                  bundle: bundle
              ) else { return [] }

        var result: [Version] = []
        var current = sourceVersion
        while current.versionName != versions.current.versionName, let next = versions.nextVersion(for: current) {
            result.append(next)
            current = next
        }
        return result
    }

    // MARK: - Private

    private func migrationStepsForStore(
        at storeURL: URL,
        toVersion destinationVersion: Version
    ) -> [CoreDataMigrationStep] {
        guard let bundle else {
            fatalError("Cant migrate without passed bundle")
        }
        guard
            let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL),
            let sourceVersion = compatibleVersionForStoreMetadata(
                metadata,
                momdSubdirectory: momdSubdirectory,
                bundle: bundle
            )
        else { fatalError("unknown store version at URL \(storeURL)") }

        migrating?(sourceVersion, destinationVersion)

        return migrationSteps(fromSourceVersion: sourceVersion, toDestinationVersion: destinationVersion)
    }

    private func migrationSteps(
        fromSourceVersion sourceVersion: Version,
        toDestinationVersion destinationVersion: Version
    ) -> [CoreDataMigrationStep] {
        guard let bundle else {
            fatalError("Cant migrate without passed bundle")
        }
        var sourceVersion = sourceVersion
        var migrationSteps = [CoreDataMigrationStep]()

        while sourceVersion.versionName != destinationVersion.versionName, let nextVersion = versions.nextVersion(for: sourceVersion) {
            let migrationStep = CoreDataMigrationStep(
                sourceVersion: sourceVersion,
                destinationVersion: nextVersion,
                momdSubdirectory: momdSubdirectory,
                bundle: bundle
            )
            migrationSteps.append(migrationStep)

            sourceVersion = nextVersion
        }

        return migrationSteps
    }

    // MARK: - WAL

    private func forceWALCheckpointingForStore(at storeURL: URL, usesPersistentHistoryTracking: Bool) {
        guard let bundle else { return }
        guard let metadata = NSPersistentStoreCoordinator.metadata(at: storeURL),
              let sourceVersion = compatibleVersionForStoreMetadata(
                  metadata,
                  momdSubdirectory: momdSubdirectory,
                  bundle: bundle
              ) else {
            return
        }

        let sourceModel = NSManagedObjectModel.managedObjectModel(
            forResource: sourceVersion.versionName,
            momdSubdirectory: momdSubdirectory,
            bundle: bundle
        )

        do {
            let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: sourceModel)

            var options: [String: Any] = [
                NSSQLitePragmasOption: ["journal_mode": "DELETE"],
                NSMigratePersistentStoresAutomaticallyOption: false,
                NSInferMappingModelAutomaticallyOption: false
            ]
            if usesPersistentHistoryTracking {
                options[NSPersistentHistoryTrackingKey] = true
            }
            let store = persistentStoreCoordinator.addPersistentStore(at: storeURL, options: options)
            try persistentStoreCoordinator.remove(store)
        } catch let error {
            fatalError("failed to force WAL checkpointing, error: \(error)")
        }
    }

    // MARK: - Version Lookup

    private func compatibleVersionForStoreMetadata(
        _ metadata: [String: Any],
        momdSubdirectory: String,
        bundle: Bundle
    ) -> Version? {
        versions.first {
            let model = NSManagedObjectModel.managedObjectModel(
                forResource: $0.versionName,
                momdSubdirectory: momdSubdirectory,
                bundle: bundle
            )
            return model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata)
        }
    }
}

private extension NSManagedObjectModel {
    static func compatibleModelForStoreMetadata(_ metadata: [String: Any]) -> NSManagedObjectModel? {
        let mainBundle = Bundle.main
        return NSManagedObjectModel.mergedModel(from: [mainBundle], forStoreMetadata: metadata)
    }
}

private extension NSPersistentStoreCoordinator {
    static func destroyStore(at storeURL: URL) {
        do {
            let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: NSManagedObjectModel())
            try persistentStoreCoordinator.destroyPersistentStore(at: storeURL, ofType: NSSQLiteStoreType, options: nil)
        } catch let error {
            fatalError("failed to destroy persistent store at \(storeURL), error: \(error)")
        }
    }

    static func replaceStore(at targetURL: URL, withStoreAt sourceURL: URL) {
        do {
            let persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: NSManagedObjectModel())
            try persistentStoreCoordinator.replacePersistentStore(
                at: targetURL,
                destinationOptions: nil,
                withPersistentStoreFrom: sourceURL,
                sourceOptions: nil,
                ofType: NSSQLiteStoreType
            )
        } catch let error {
            fatalError("failed to replace persistent store at \(targetURL) with \(sourceURL), error: \(error)")
        }
    }

    static func metadata(at storeURL: URL) -> [String: Any]? {
        try? NSPersistentStoreCoordinator.metadataForPersistentStore(
            ofType: NSSQLiteStoreType,
            at: storeURL,
            options: nil
        )
    }

    func addPersistentStore(at storeURL: URL, options: [AnyHashable: Any]) -> NSPersistentStore {
        do {
            return try addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: options
            )
        } catch let error {
            fatalError("failed to add persistent store to coordinator, error: \(error)")
        }
    }
}
