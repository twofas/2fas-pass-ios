// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common
import UIKit
import Data
import CommonUI

enum TrashDestination: RouterDestination {
    case confirmDelete(id: ItemID, onFinish: (Bool) -> Void)
    case upgradePlanPrompt(limitItems: Int)
    
    var id: String {
        switch self {
        case .confirmDelete(let id, _): "confirmDelete_\(id)"
        case .upgradePlanPrompt: "upgradePlanPrompt"
        }
    }
}

private class IconFetcherProxy: RemoteImageCollectionFetcher {
    
    let interactor: TrashModuleInteracting
    
    init(interactor: TrashModuleInteracting) {
        self.interactor = interactor
    }
    
    func cachedImage(from url: URL) -> Data? {
        interactor.cachedImage(from: url)
    }
    
    func fetchImage(from url: URL) async throws -> Data {
        try await interactor.fetchIconImage(from: url)
    }
}

@Observable
final class TrashPresenter {
    var showMenu: ((Bool) -> Void)?
    var isTrashEmpty = true
    var items: [TrashItemData] = []
    
    private(set) var icons: [ItemID: IconContent] = [:]
    private let iconDataSource: RemoteImageCollectionDataSource<TrashItemData>
    
    private let interactor: TrashModuleInteracting
    private let notificationCenter: NotificationCenter
    
    var destination: TrashDestination?
    
    init(interactor: TrashModuleInteracting) {
        self.interactor = interactor
        self.iconDataSource = RemoteImageCollectionDataSource(fetcher: IconFetcherProxy(interactor: interactor))
        self.notificationCenter = .default
        
        notificationCenter.addObserver(self, selector: #selector(syncFinished), name: .webDAVStateChange, object: nil)
        notificationCenter.addObserver(self, selector: #selector(iCloudSyncFinished), name: .cloudStateChanged, object: nil)
    }
    
    deinit {
        notificationCenter.removeObserver(self)
    }
}

extension TrashPresenter {
    
    @MainActor
    func onAppear() {
        iconDataSource.onImageFetchResult = { [weak self] item, url, result in
            if let imageData = try? result.get(), let image = UIImage(data: imageData) {
                self?.icons[item.id] = .icon(image)
            }
        }
        
        reload()
    }
    
    @MainActor
    func onAppear(for item: TrashItemData) {
        switch item.icon {
        case .login(let iconType):
            switch iconType {
            case .domainIcon:
                let label = Config.defaultIconLabel(forName: item.name ?? "")
                icons[item.id] = .label(label, color: nil)

                if let url = iconType.iconURL {
                    if let cachedData = iconDataSource.cachedImage(from: url), let image = UIImage(data: cachedData) {
                        icons[item.id] = .icon(image)
                    }
                    iconDataSource.fetchImage(from: url, for: item)
                }

            case .customIcon(let url):
                let label = Config.defaultIconLabel(forName: item.name ?? "")
                icons[item.id] = .label(label, color: nil)

                if let cachedData = iconDataSource.cachedImage(from: url), let image = UIImage(data: cachedData) {
                    icons[item.id] = .icon(image)
                }
                iconDataSource.fetchImage(from: url, for: item)

            case .label(labelTitle: let title, labelColor: let color):
                icons[item.id] = .label(title, color: color)
            }

        case .contentType(let contentType):
            icons[item.id] = .contentType(contentType)

        case .paymentCard(let issuer):
            if let issuer, let paymentCardIssuer = PaymentCardIssuer(rawValue: issuer) {
                icons[item.id] = .icon(paymentCardIssuer.icon)
            } else {
                icons[item.id] = .contentType(.paymentCard)
            }
        }
    }
    
    @MainActor
    func onDisappear(for item: TrashItemData) {
        iconDataSource.cancelFetches(for: item)
    }
    
    func onRestore(itemID: ItemID) {
        if interactor.canRestore {
            interactor.restore(with: itemID)
            reload()
        } else {
            destination = .upgradePlanPrompt(limitItems: interactor.currentPlanLimitItems)
        }
    }
    
    func onDelete(itemID: ItemID) {
        destination = .confirmDelete(id: itemID, onFinish: { [weak self] confirm in
            self?.destination = nil
            
            if confirm {
                self?.interactor.delete(with: itemID)
                self?.reload()
            }
        })
    }
    
    func onEmptyTrash() {
        interactor.emptyTrash()
        reload()
    }
    
    func onRestoreAll() {
        interactor.restoreAll()
        reload()
    }
}

private extension TrashPresenter {
    func reload() {
        isTrashEmpty = interactor.isTrashEmpty
        showMenu?(!isTrashEmpty)
        items = interactor.list()
            .compactMap({ item -> TrashItemData? in
                switch item.trashedStatus {
                case .no: return nil
                case .yes(let trashingDate):
                    switch item {
                    case .login(let loginItem):
                        return TrashItemData(
                            itemID: loginItem.id,
                            name: loginItem.name,
                            description: loginItem.username,
                            deletedDate: trashingDate,
                            icon: .login(loginItem.iconType)
                        )
                    case .secureNote(let noteItem):
                        return TrashItemData(
                            itemID: noteItem.id,
                            name: noteItem.name,
                            description: nil,
                            deletedDate: trashingDate,
                            icon: .contentType(.secureNote)
                        )
                    case .paymentCard(let paymentCardItem):
                        return TrashItemData(
                            itemID: paymentCardItem.id,
                            name: paymentCardItem.name,
                            description: paymentCardItem.content.cardNumberMask?.formatted(.paymentCardNumberMask),
                            deletedDate: trashingDate,
                            icon: .paymentCard(issuer: paymentCardItem.content.cardIssuer)
                        )
                    case .raw:
                        return nil
                    }
                }
            })
    }
    
    @objc
    func syncFinished(_ event: Notification) {
        guard let e = event.userInfo?[Notification.webDAVState] as? WebDAVState, e == .synced else {
            return
        }
        DispatchQueue.main.async {
            self.reload()
        }
    }
    
    @objc
    func iCloudSyncFinished() {
        DispatchQueue.main.async {
            self.reload()
        }
    }
}
