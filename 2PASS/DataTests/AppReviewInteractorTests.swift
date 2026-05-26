// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Testing
import Foundation
@testable import Data
import Common

@Suite struct AppReviewInteractorTests {

    private static let fixedNow = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private static let installAgeBoundary = TimeInterval(Config.AppReview.minimumInstallAge.components.seconds)
    private static let yieldDeadline: Duration = .milliseconds(200)

    // MARK: - All gates pass

    @Test func yields_whenAllGatesPass_andUserIsPremium() async {
        let center = NotificationCenter()
        let repo = Self.eligibleRepo()
        let interactor = Self.makeInteractor(repo: repo, isPremium: true, center: center)

        let yielded = await Self.waitForReviewRequest(on: interactor, posting: center)

        #expect(yielded == true)
        #expect(repo.capturedLastAppReviewPromptDate == Self.fixedNow)
    }

    // MARK: - Payment filter

    @Test func doesNotYield_whenUserIsNotPremium() async {
        let center = NotificationCenter()
        let repo = Self.eligibleRepo()
        let interactor = Self.makeInteractor(repo: repo, isPremium: false, center: center)

        let yielded = await Self.waitForReviewRequest(on: interactor, posting: center)

        #expect(yielded == false)
        #expect(repo.capturedLastAppReviewPromptDate == nil)
    }

    // MARK: - Install-age gate

    @Test func doesNotYield_whenDateOfFirstRunIsNil() async {
        let center = NotificationCenter()
        let repo = Self.eligibleRepo().withDateOfFirstRun(nil)
        let interactor = Self.makeInteractor(repo: repo, isPremium: true, center: center)

        let yielded = await Self.waitForReviewRequest(on: interactor, posting: center)

        #expect(yielded == false)
        #expect(repo.capturedLastAppReviewPromptDate == nil)
    }

    @Test func doesNotYield_whenInstalledLessThanOneDayAgo() async {
        let center = NotificationCenter()
        let recentInstall = Self.fixedNow.addingTimeInterval(-Self.installAgeBoundary + 60)
        let repo = Self.eligibleRepo().withDateOfFirstRun(recentInstall)
        let interactor = Self.makeInteractor(repo: repo, isPremium: true, center: center)

        let yielded = await Self.waitForReviewRequest(on: interactor, posting: center)

        #expect(yielded == false)
        #expect(repo.capturedLastAppReviewPromptDate == nil)
    }

    // MARK: - Has-items gate

    @Test func doesNotYield_whenVaultIsEmpty() async {
        let center = NotificationCenter()
        let repo = Self.eligibleRepo().withListItems { _ in [] }
        let interactor = Self.makeInteractor(repo: repo, isPremium: true, center: center)

        let yielded = await Self.waitForReviewRequest(on: interactor, posting: center)

        #expect(yielded == false)
        #expect(repo.capturedLastAppReviewPromptDate == nil)
    }

    // MARK: - No in-app cool-down

    @Test func yields_evenWhenPriorPromptIsVeryRecent() async {
        let center = NotificationCenter()
        let recentPrompt = Self.fixedNow.addingTimeInterval(-60)
        let repo = Self.eligibleRepo().withLastAppReviewPromptDate(recentPrompt)
        let interactor = Self.makeInteractor(repo: repo, isPremium: true, center: center)

        let yielded = await Self.waitForReviewRequest(on: interactor, posting: center)

        #expect(yielded == true)
        #expect(repo.capturedLastAppReviewPromptDate == Self.fixedNow)
    }

    // MARK: - Fixtures

    private static func eligibleRepo() -> MockMainRepository {
        MockMainRepository()
            .withDateOfFirstRun(fixedNow.addingTimeInterval(-installAgeBoundary * 2))
            .withListItems { _ in [Self.makeAnyItem()] }
    }

    private static func makeInteractor(
        repo: MockMainRepository,
        isPremium: Bool,
        center: NotificationCenter
    ) -> AppReviewInteractor {
        AppReviewInteractor(
            mainRepository: repo,
            currentDateInteractor: StubCurrentDateInteractor(date: fixedNow),
            paymentStatusInteractor: StubPaymentStatusInteractor(isPremium: isPremium),
            notificationCenter: center
        )
    }

    /// Races "first stream event" against `yieldDeadline`. Returns `true` on yield within
    /// the deadline, `false` on timeout.
    private static func waitForReviewRequest(
        on interactor: AppReviewInteractor,
        posting center: NotificationCenter
    ) async -> Bool {
        let stream = interactor.reviewRequests
        return await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                for await _ in stream {
                    return true
                }
                return false
            }
            group.addTask {
                // Brief delay so the consuming Task's `for await` lands on the upstream
                // sequence before we post — otherwise the post races the subscription.
                try? await Task.sleep(for: .milliseconds(20))
                center.post(name: .paymentStatusChanged, object: nil)
                try? await Task.sleep(for: yieldDeadline)
                return false
            }
            let first = await group.next() ?? false
            group.cancelAll()
            return first
        }
    }

    private final class StubCurrentDateInteractor: CurrentDateInteracting {
        let currentDate: Date
        init(date: Date) { self.currentDate = date }
    }

    private final class StubPaymentStatusInteractor: PaymentStatusInteracting {
        let isPremium: Bool
        init(isPremium: Bool) { self.isPremium = isPremium }
        var userId: String? { fatalError("not used in AppReviewInteractorTests") }
        var entitlements: SubscriptionPlan.Entitlements { fatalError("not used in AppReviewInteractorTests") }
        var plan: SubscriptionPlan { fatalError("not used in AppReviewInteractorTests") }
        func fetchRenewPrice() async -> String? { fatalError("not used in AppReviewInteractorTests") }
    }

    private static func makeAnyItem() -> ItemData {
        .login(LoginItemData(
            id: ItemID(),
            vaultId: VaultID(),
            metadata: ItemMetadata(
                creationDate: Date(timeIntervalSince1970: 0),
                modificationDate: Date(timeIntervalSince1970: 0),
                protectionLevel: .normal,
                trashedStatus: .no,
                tagIds: nil
            ),
            name: nil,
            content: LoginItemContent(
                name: nil,
                username: nil,
                password: nil,
                notes: nil,
                iconType: .domainIcon(""),
                uris: nil
            )
        ))
    }
}
