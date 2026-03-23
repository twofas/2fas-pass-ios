// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import UIKit
import SwiftUI
import Common

enum ShareLinkItemDestination: RouterDestination {
    case password(initialPassword: String, onSave: (String) -> Void, onCancel: () -> Void)
    case share(title: String, url: URL, onComplete: () -> Void)

    var id: String {
        switch self {
        case .password: "password"
        case .share: "share"
        }
    }
}

@Observable
final class ShareLinkItemPresenter {
    let itemID: ItemID

    let shortDurations: [DateComponents] = [
        DateComponents(minute: 5),
        DateComponents(minute: 30),
        DateComponents(hour: 1),
    ]
    let longDurations: [DateComponents] = [
        DateComponents(day: 1),
        DateComponents(day: 7),
        DateComponents(day: 30),
    ]
    let expirationFormat: Duration.UnitsFormatStyle = .units(allowed: [.days, .hours, .minutes], width: .abbreviated)
    private var allDurations: [DateComponents] { shortDurations + longDurations }

    var name: String = ""
    var iconContent: IconContent?
    private(set) var cardIssuer: PaymentCardIssuer?
    private(set) var cardNumberMask: String?
    var isPaymentCard: Bool { cardIssuer != nil || cardNumberMask != nil }
    var isUploading: Bool = false
    var isExpanded: Bool = false
    var isSuccess: Bool = false

    var selectedExpiration: DateComponents = DateComponents(minute: 5)
    var isOneTimeAccess: Bool = false
    var password: String = ""
    var destination: ShareLinkItemDestination?
    var shareURL: URL?

    private let interactor: ShareLinkItemModuleInteracting
    private var fetchingIconTask: Task<Void, Error>?
    private var continueTask: Task<Void, Never>?

    init(itemID: ItemID, interactor: ShareLinkItemModuleInteracting) {
        self.itemID = itemID
        self.interactor = interactor
    }

    func onAppear() {
        guard let item = interactor.fetchItem(for: itemID) else { return }

        name = item.name ?? ""

        if let loginItem = item.asLoginItem {
            loadLoginIcon(loginItem)
        } else if let card = item.asPaymentCard {
            iconContent = .contentType(item.contentType)
            cardIssuer = card.content.cardIssuer.flatMap(PaymentCardIssuer.init(rawValue:))
            cardNumberMask = card.content.cardNumberMask
        } else {
            iconContent = .contentType(item.contentType)
        }

        if let config = interactor.shareLinkConfig {
            if let expiration = allDurations.first(where: {
                $0.totalSeconds == Int(config.expirationSeconds)
            }) {
                selectedExpiration = expiration
            }
            isOneTimeAccess = config.isOneTimeAccess
        }
    }

    func onCopyPassword() {
        guard !password.isEmpty else {
            ToastPresenter.shared.present(
                .passwordErrorCopyPassword,
                style: .failure
            )
            return
        }

        UIPasteboard.general.string = password
        ToastPresenter.shared.presentPasswordCopied()
    }

    func onAccessPasswordTapped() {
        destination = .password(
            initialPassword: password,
            onSave: { [weak self] password in
                self?.password = password
                self?.destination = nil
            },
            onCancel: { [weak self] in
                self?.destination = nil
            }
        )
    }

    func onContinue() {
        isUploading = true

        continueTask = Task { @MainActor in
            do {
                let url = try await interactor.shareItem(
                    id: itemID,
                    password: password.isEmpty ? nil : password,
                    validForSeconds: selectedExpiration.totalSeconds,
                    singleUse: isOneTimeAccess
                )
                guard !Task.isCancelled else { return }
                shareURL = url
                interactor.saveShareLinkConfig(
                    expirationSeconds: TimeInterval(selectedExpiration.totalSeconds),
                    isOneTimeAccess: isOneTimeAccess
                )
                withAnimation(.smooth(duration: 0.4)) {
                    isSuccess = true
                    isExpanded = true
                }
            } catch {
                guard !Task.isCancelled else { return }
                isUploading = false
            }
        }
    }

    func onShare() {
        guard let shareURL else { return }
        destination = .share(
            title: name,
            url: shareURL,
            onComplete: { [weak self] in
                self?.destination = nil
            }
        )
    }

    func onDisappear() {
        fetchingIconTask?.cancel()
        continueTask?.cancel()
    }

    private func loadLoginIcon(_ loginItem: LoginItemData) {
        switch loginItem.iconType {
        case .label(let title, let color):
            iconContent = .label(title, color: color)

        case .customIcon(let url):
            iconContent = defaultIconContent
            fetchIcon(from: url)

        case .domainIcon:
            iconContent = defaultIconContent
            if let url = loginItem.iconType.iconURL {
                fetchIcon(from: url)
            }
        }
    }

    private var defaultIconContent: IconContent {
        .label(Config.defaultIconLabel(forName: name), color: nil)
    }

    private func fetchIcon(from iconURL: URL) {
        fetchingIconTask?.cancel()
        fetchingIconTask = Task { @MainActor in
            if let imageData = try? await interactor.fetchIconImage(from: iconURL),
               let image = UIImage(data: imageData) {
                iconContent = .icon(image)
            }
        }
    }
}

extension DateComponents {
    
    var duration: Duration {
        .seconds(totalSeconds)
    }
    
    fileprivate var totalSeconds: Int {
        (day ?? 0) * 86_400 + (hour ?? 0) * 3600 + (minute ?? 0) * 60
    }
}
