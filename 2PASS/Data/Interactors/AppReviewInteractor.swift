// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import Common

public protocol AppReviewInteracting: AnyObject {
    var reviewRequests: AsyncStream<Void> { get }
}

final class AppReviewInteractor: AppReviewInteracting {
    private let mainRepository: MainRepository
    private let currentDateInteractor: CurrentDateInteracting
    private let paymentStatusInteractor: PaymentStatusInteracting
    private let notificationCenter: NotificationCenter

    init(
        mainRepository: MainRepository,
        currentDateInteractor: CurrentDateInteracting,
        paymentStatusInteractor: PaymentStatusInteracting,
        notificationCenter: NotificationCenter = .default
    ) {
        self.mainRepository = mainRepository
        self.currentDateInteractor = currentDateInteractor
        self.paymentStatusInteractor = paymentStatusInteractor
        self.notificationCenter = notificationCenter
    }

    var reviewRequests: AsyncStream<Void> {
        let upstream = notificationCenter.notifications(named: .paymentStatusChanged)
        return AsyncStream { continuation in
            let task = Task { @MainActor [weak self] in
                for await _ in upstream {
                    guard let self else { continue }
                    guard self.paymentStatusInteractor.isPremium else { continue }
                    let current = self.currentDateInteractor.currentDate
                    guard self.shouldPromptForReview(at: current) else { continue }
                    self.markReviewPromptShown(at: current)
                    continuation.yield()
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    @MainActor
    private func shouldPromptForReview(at current: Date) -> Bool {
        !mainRepository.listItems(options: .allNotTrashed).isEmpty
    }

    @MainActor
    private func markReviewPromptShown(at current: Date) {
        mainRepository.setLastAppReviewPromptDate(current)
    }
}
