// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import CoreData

final class PersistentHistoryTracker {
    private static let keyPrefix = "CoreDataStack.PersistentHistory"

    private let storeName: String
    private let transactionAuthor: String
    private let defaults: UserDefaults?
    var logError: ((LogMessage) -> Void)?

    private var lastHistoryToken: NSPersistentHistoryToken?
    private var lastHistoryDate: Date?
    private var didRestoreHistoryState = false
    private var remoteChangeObserver: NSObjectProtocol?

    static func clearState(forStoreName name: String, storeInGroup: Bool) {
        guard let defaults = defaults(storeInGroup: storeInGroup) else {
            return
        }

        let prefix = "\(keyPrefix).\(name)."
        let keys = defaults.dictionaryRepresentation().keys
        keys.filter { $0.hasPrefix(prefix) }.forEach { key in
            defaults.removeObject(forKey: key)
        }
    }

    private static func defaults(storeInGroup: Bool) -> UserDefaults? {
        if storeInGroup {
            return UserDefaults(suiteName: Config.suiteName)
        } else {
            return .standard
        }
    }
    
    init(storeName: String, transactionAuthor: String, storeInGroup: Bool) {
        self.storeName = storeName
        self.transactionAuthor = transactionAuthor
        self.defaults = Self.defaults(storeInGroup: storeInGroup)
    }

    deinit {
        if let remoteChangeObserver {
            NotificationCenter.default.removeObserver(remoteChangeObserver)
        }
    }

    func configureStoreDescription(_ description: NSPersistentStoreDescription) {
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
    }

    func configureContext(_ context: NSManagedObjectContext) {
        context.transactionAuthor = transactionAuthor
    }

    func startObservingRemoteChangesIfNeeded(in container: NSPersistentContainer) {
        guard remoteChangeObserver == nil else {
            return
        }

        restoreHistoryStateIfNeeded()

        remoteChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator,
            queue: nil
        ) { [weak self, weak container] _ in
            guard let self, let container else {
                return
            }
            self.processPersistentHistory(in: container)
        }

        processPersistentHistory(in: container)
    }

    private func processPersistentHistory(in container: NSPersistentContainer) {
        restoreHistoryStateIfNeeded()

        let viewContext = container.viewContext
        viewContext.perform { [weak self] in
            guard let self else { return }

            let request = NSPersistentHistoryChangeRequest.fetchHistory(after: self.lastHistoryToken)
            guard let fetchRequest = NSPersistentHistoryTransaction.fetchRequest else {
                return
            }
            fetchRequest.predicate = NSPredicate(format: "author == nil OR author != %@", self.transactionAuthor)
            request.fetchRequest = fetchRequest

            do {
                guard let result = try viewContext.execute(request) as? NSPersistentHistoryResult,
                      let transactions = result.result as? [NSPersistentHistoryTransaction],
                      !transactions.isEmpty else {
                    self.prunePersistentHistoryIfNeeded(on: viewContext)
                    return
                }

                self.lastHistoryToken = transactions.last?.token
                self.lastHistoryDate = transactions.last?.timestamp ?? self.lastHistoryDate
                self.persistHistoryState()

                let changeSets = transactions.compactMap { $0.objectIDNotification().userInfo }
                changeSets.forEach { changeSet in
                    NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changeSet, into: [viewContext])
                }

                self.prunePersistentHistoryIfNeeded(on: viewContext)
            } catch {
                self.log(error, prefix: "processing")
            }
        }
    }

    private var historyStateKeyPrefix: String {
        "\(Self.keyPrefix).\(storeName).\(transactionAuthor)"
    }

    private var historyTokenKey: String {
        "\(historyStateKeyPrefix).token"
    }

    private var historyDateKey: String {
        "\(historyStateKeyPrefix).date"
    }

    private func restoreHistoryStateIfNeeded() {
        guard didRestoreHistoryState == false else {
            return
        }

        didRestoreHistoryState = true
        guard let defaults else {
            return
        }

        if let date = defaults.object(forKey: historyDateKey) as? Date {
            lastHistoryDate = date
        }

        guard let tokenData = defaults.data(forKey: historyTokenKey) else {
            return
        }

        do {
            let token = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: NSPersistentHistoryToken.self,
                from: tokenData
            )
            lastHistoryToken = token
        } catch {
            defaults.removeObject(forKey: historyTokenKey)
            defaults.removeObject(forKey: historyDateKey)
            self.log(error, prefix: "restoring")
        }
    }

    private func persistHistoryState() {
        guard let defaults, let lastHistoryToken else {
            return
        }

        do {
            let tokenData = try NSKeyedArchiver.archivedData(
                withRootObject: lastHistoryToken,
                requiringSecureCoding: true
            )
            defaults.set(tokenData, forKey: historyTokenKey)
            defaults.set(lastHistoryDate ?? Date(), forKey: historyDateKey)
        } catch {
            self.log(error, prefix: "persisting")
        }
    }

    private func prunePersistentHistoryIfNeeded(on context: NSManagedObjectContext) {
        guard let defaults,
              let pruneDate = oldestProcessedHistoryDate(defaults: defaults) else {
            return
        }

        let deleteRequest = NSPersistentHistoryChangeRequest.deleteHistory(before: pruneDate)

        do {
            _ = try context.execute(deleteRequest)
        } catch {
            self.log(error, prefix: "deleting")
        }
    }

    private func oldestProcessedHistoryDate(defaults: UserDefaults) -> Date? {
        let prefix = "\(Self.keyPrefix).\(storeName)."
        let dateSuffix = ".date"

        let allDates = defaults.dictionaryRepresentation().compactMap { key, value -> Date? in
            guard key.hasPrefix(prefix), key.hasSuffix(dateSuffix), let date = value as? Date else {
                return nil
            }
            return date
        }

        return allDates.min()
    }

    private func log(_ error: Error, prefix: String) {
        let nserror = error as NSError
        // swiftlint:disable line_length
        let message: LogMessage = "Unresolved error while \(prefix) persistent history state: \(nserror), \(nserror.userInfo), for stack: \(String(describing: storeName), privacy: .public)"
        // swiftlint:enable line_length
        logError?(message)
    }
}
