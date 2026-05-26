// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Testing
import Foundation
import os
@testable import Common

@Suite struct NotificationsTypedMessageTests {

    // MARK: - Test fixtures

    final class TestSubject {}

    struct PingMessage: Notifications.AsyncMessage {
        typealias Subject = TestSubject
        let value: Int
    }

    struct PongMessage: Notifications.AsyncMessage {
        typealias Subject = TestSubject
        let text: String
    }

    struct UIPing: Notifications.MainActorMessage {
        typealias Subject = TestSubject
        let value: Int
    }

    final class Counter: @unchecked Sendable {
        private let storage = OSAllocatedUnfairLock<[Int]>(initialState: [])
        func record(_ value: Int) { storage.withLock { $0.append(value) } }
        var values: [Int] { storage.withLock { $0 } }
        var count: Int { storage.withLock { $0.count } }
    }

    // MARK: - Round-trip

    @Test func asyncMessageRoundTripPreservesPayload() async throws {
        let center = NotificationCenter()
        async let received = collect(of: PingMessage.self, count: 1, on: center)
        try await Task.sleep(for: .milliseconds(30))
        center.post(PingMessage(value: 42))
        let messages = try await received
        #expect(messages.map(\.value) == [42])
    }

    @Test func messagesIgnoresOtherMessageTypes() async throws {
        let center = NotificationCenter()
        async let received = collect(of: PingMessage.self, count: 1, on: center)
        try await Task.sleep(for: .milliseconds(30))
        center.post(PongMessage(text: "should be filtered out"))
        center.post(PingMessage(value: 7))
        let messages = try await received
        #expect(messages.map(\.value) == [7])
    }

    // MARK: - Multi-subscriber fan-out

    @Test func multiSubscriberFanOut() async throws {
        let center = NotificationCenter()
        async let firstStream = collect(of: PingMessage.self, count: 3, on: center)
        async let secondStream = collect(of: PingMessage.self, count: 3, on: center)
        try await Task.sleep(for: .milliseconds(30))
        center.post(PingMessage(value: 1))
        center.post(PingMessage(value: 2))
        center.post(PingMessage(value: 3))
        let (first, second) = try await (firstStream, secondStream)
        #expect(first.map(\.value) == [1, 2, 3])
        #expect(second.map(\.value) == [1, 2, 3])
    }

    // MARK: - Subject scoping

    @Test func subjectScopingFiltersByIdentity() async throws {
        let center = NotificationCenter()
        let subjectA = TestSubject()
        let subjectB = TestSubject()
        async let onlyA = collect(of: PingMessage.self, count: 1, subject: subjectA, on: center)
        try await Task.sleep(for: .milliseconds(30))
        center.post(PingMessage(value: 99), subject: subjectB)
        center.post(PingMessage(value: 7), subject: subjectA)
        let messages = try await onlyA
        #expect(messages.map(\.value) == [7])
    }

    @Test func nilSubjectObserverReceivesAllPosts() async throws {
        let center = NotificationCenter()
        let subjectA = TestSubject()
        async let received = collect(of: PingMessage.self, count: 2, on: center)
        try await Task.sleep(for: .milliseconds(30))
        center.post(PingMessage(value: 1), subject: subjectA)
        center.post(PingMessage(value: 2))
        let messages = try await received
        #expect(messages.map(\.value) == [1, 2])
    }

    // MARK: - Synchronous observer

    @Test func synchronousObserverRunsBeforePostReturns() {
        let center = NotificationCenter()
        let counter = Counter()
        let token = center.addObserver(of: PingMessage.self) { message in
            counter.record(message.value)
        }
        center.post(PingMessage(value: 7))
        #expect(counter.values == [7])
        token.cancel()
    }

    @Test func cancellationStopsDelivery() {
        let center = NotificationCenter()
        let counter = Counter()
        let token = center.addObserver(of: PingMessage.self) { message in
            counter.record(message.value)
        }
        center.post(PingMessage(value: 1))
        token.cancel()
        center.post(PingMessage(value: 2))
        #expect(counter.values == [1])
    }

    @Test func cancellationIsIdempotent() {
        let center = NotificationCenter()
        let token = center.addObserver(of: PingMessage.self) { _ in }
        token.cancel()
        token.cancel()
    }

    @Test func tokenDeinitRemovesObserver() {
        let center = NotificationCenter()
        let counter = Counter()
        do {
            let token = center.addObserver(of: PingMessage.self) { message in
                counter.record(message.value)
            }
            center.post(PingMessage(value: 1))
            _ = token
        }
        center.post(PingMessage(value: 2))
        #expect(counter.values == [1])
    }

    // MARK: - MainActorMessage delivery

    @MainActor
    @Test func mainActorMessageDeliversOnMain() {
        let center = NotificationCenter()
        let counter = Counter()
        let token = center.addObserver(of: UIPing.self) { message in
            counter.record(message.value)
        }
        center.post(UIPing(value: 5))
        #expect(counter.values == [5])
        token.cancel()
    }

    // MARK: - Default-name derivation

    @Test func defaultNameIsDerivedFromQualifiedTypeIdentity() {
        // Two unrelated types share the leaf name "Inner" but live in different namespaces.
        // The default name uses `String(reflecting:)`, which qualifies with the enclosing
        // type, so the two notification names must differ.
        #expect(NamespaceA.Inner.name != NamespaceB.Inner.name)
    }

    enum NamespaceA {
        struct Inner: Notifications.AsyncMessage {
            typealias Subject = TestSubject
        }
    }

    enum NamespaceB {
        struct Inner: Notifications.AsyncMessage {
            typealias Subject = TestSubject
        }
    }

    // MARK: - Helpers

    private func collect<M: Notifications.AsyncMessage>(
        of type: M.Type,
        count: Int,
        subject: M.Subject? = nil,
        on center: NotificationCenter
    ) async -> [M] {
        var results: [M] = []
        for await message in center.messages(of: type, from: subject) {
            results.append(message)
            if results.count == count { break }
        }
        return results
    }
}
