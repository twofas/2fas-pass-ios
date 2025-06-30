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
    case confirmDelete(id: PasswordID, onFinish: (Bool) -> Void)
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
    var passwords: [TrashPasswordData] = []
    
    private(set) var icons: [PasswordID: IconContent] = [:]
    private let iconDataSource: RemoteImageCollectionDataSource<TrashPasswordData>
    
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
        iconDataSource.onImageFetchResult = { [weak self] password, url, result in
            if let imageData = try? result.get(), let image = UIImage(data: imageData) {
                self?.icons[password.id] = .icon(image)
            }
        }
        
        reload()
    }
    
    @MainActor
    func onAppear(for password: TrashPasswordData) {
        switch password.iconType {
        case .domainIcon:
            let label = Config.defaultIconLabel(forName: password.name ?? "")
            icons[password.id] = .label(label, color: nil)
            
            if let url = password.iconType.iconURL {
                if let cachedData = iconDataSource.cachedImage(from: url), let image = UIImage(data: cachedData) {
                    icons[password.id] = .icon(image)
                }
                iconDataSource.fetchImage(from: url, for: password)
            }
            
        case .customIcon(let url):
            let label = Config.defaultIconLabel(forName: password.name ?? "")
            icons[password.id] = .label(label, color: nil)
            
            if let cachedData = iconDataSource.cachedImage(from: url), let image = UIImage(data: cachedData) {
                icons[password.id] = .icon(image)
            }
            iconDataSource.fetchImage(from: url, for: password)
            
        case .label(labelTitle: let title, labelColor: let color):
            icons[password.id] = .label(title, color: color)
        }
    }
    
    @MainActor
    func onDisappear(for password: TrashPasswordData) {
        iconDataSource.cancelFetches(for: password)
    }
    
    func onRestore(passwordID: PasswordID) {
        if interactor.canRestore {
            interactor.restore(with: passwordID)
            reload()
        } else {
            destination = .upgradePlanPrompt(limitItems: interactor.currentPlanLimitItems)
        }
    }
    
    func onDelete(passwordID: PasswordID) {
        destination = .confirmDelete(id: passwordID, onFinish: { [weak self] confirm in
            self?.destination = nil
            
            if confirm {
                self?.interactor.delete(with: passwordID)
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
        passwords = interactor.list()
            .compactMap({ password in
                switch password.trashedStatus {
                case .no: nil
                case .yes(let trashingDate):
                    TrashPasswordData(
                        passwordID: password.passwordID,
                        name: password.name,
                        username: password.username,
                        deletedDate: trashingDate,
                        iconType: password.iconType
                    )
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
