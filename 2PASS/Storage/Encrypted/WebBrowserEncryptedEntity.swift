// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import CoreData
import Common

final class WebBrowserEncryptedEntity: NSManagedObject {}

extension WebBrowserEncryptedEntity {
    @nonobjc static let entityName = "WebBrowserEncryptedEntity"
    @nonobjc static func fetchRequest() -> NSFetchRequest<WebBrowserEncryptedEntity> {
        NSFetchRequest<WebBrowserEncryptedEntity>(entityName: entityName)
    }
    
    @NSManaged var extensionName: Data
    @NSManaged var firstConnectionDate: Date
    @NSManaged var lastConnectionDate: Date
    @NSManaged var name: Data
    @NSManaged var nextSessionId: Data?
    @NSManaged var publicKey: Data
    @NSManaged var version: Data
    @NSManaged var webBrowserID: UUID
    
}

extension WebBrowserEncryptedEntity : Identifiable {}

extension WebBrowserEncryptedEntity {
    
    @discardableResult
    static func create(from data: WebBrowserEncryptedData, on context: NSManagedObjectContext) -> WebBrowserEncryptedEntity {
        let entity = WebBrowserEncryptedEntity(context: context)
        entity.webBrowserID = data.id
        entity.update(with: data)
        return entity
    }
    
    static func find(id: UUID, on context: NSManagedObjectContext) -> WebBrowserEncryptedEntity? {
        let request = WebBrowserEncryptedEntity.fetchRequest()
        request.predicate = NSPredicate(format: "%K == %@", #keyPath(WebBrowserEncryptedEntity.webBrowserID), id as CVarArg)
        request.fetchLimit = 1
        
        do {
            guard let result = try context.fetch(request).first else {
                return nil
            }
            return result
        } catch {
            let err = error as NSError
            Log("WebBrowserEntity in Storage find: \(err.localizedDescription)", module: .storage)
            return nil
        }
    }
    
    static func list(on context: NSManagedObjectContext) -> [WebBrowserEncryptedEntity] {
        let request = WebBrowserEncryptedEntity.fetchRequest()
        
        do {
            return try context.fetch(request)
        } catch {
            let err = error as NSError
            // swiftlint:disable line_length
            Log("WebBrowserEntity in Storage list: \(err.localizedDescription)", module: .storage)
            // swiftlint:enable line_length
            return []
        }
    }
}

extension WebBrowserEncryptedEntity {
    
    func update(with data: WebBrowserEncryptedData) {
        guard data.id == webBrowserID else {
            return
        }
        
        self.publicKey = data.publicKey
        self.name = data.name
        self.version = data.version
        self.extensionName = data.extName
        self.firstConnectionDate = data.firstConnectionDate
        self.lastConnectionDate = data.lastConnectionDate
        self.nextSessionId = data.nextSessionID
    }
}

extension WebBrowserEncryptedData {
    
    init(_ entity: WebBrowserEncryptedEntity) {
        self.init(
            id: entity.webBrowserID,
            publicKey: entity.publicKey,
            name: entity.name,
            version: entity.version,
            extName: entity.extensionName,
            firstConnectionDate: entity.firstConnectionDate,
            lastConnectionDate: entity.lastConnectionDate,
            nextSessionID: entity.nextSessionId
        )
    }
}
