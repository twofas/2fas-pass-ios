// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import os

// MARK: - Typed-message backport of iOS 26's NotificationCenter.AsyncMessage / .MainActorMessage

public enum Notifications {

    public protocol AsyncMessage: Sendable {
        associatedtype Subject: AnyObject
        static var name: Notification.Name { get }
    }

    public protocol MainActorMessage {
        associatedtype Subject: AnyObject
        static var name: Notification.Name { get }
    }

    public typealias MessageSequence<M> = AsyncCompactMapSequence<NotificationCenter.Notifications, M>

    public final class ObservationToken: @unchecked Sendable {
        private let token: NSObjectProtocol
        private let center: NotificationCenter
        private let cancelled = OSAllocatedUnfairLock<Bool>(initialState: false)

        fileprivate init(token: NSObjectProtocol, center: NotificationCenter) {
            self.token = token
            self.center = center
        }

        public func cancel() {
            let shouldRemove = cancelled.withLock { wasCancelled in
                guard !wasCancelled else { return false }
                wasCancelled = true
                return true
            }
            if shouldRemove {
                center.removeObserver(token)
            }
        }

        deinit { cancel() }
    }
}

extension Notifications.AsyncMessage {
    public static var name: Notification.Name {
        Notification.Name("Notifications.\(String(reflecting: Self.self))")
    }
}

extension Notifications.MainActorMessage {
    public static var name: Notification.Name {
        Notification.Name("Notifications.\(String(reflecting: Self.self))")
    }
}

// MARK: - Internals

private let messagePayloadKey = "Notifications.payload"

private struct AnyMessageBox: @unchecked Sendable {
    let value: Any
}

// MARK: - Module-scope public aliases

public typealias NotificationsAsyncMessage = Notifications.AsyncMessage
public typealias NotificationsMainActorMessage = Notifications.MainActorMessage
public typealias NotificationsObservationToken = Notifications.ObservationToken

// MARK: - NotificationCenter extensions: AsyncMessage

extension NotificationCenter {

    public func post<M: NotificationsAsyncMessage>(_ message: M, subject: M.Subject? = nil) {
        post(name: M.name, object: subject, userInfo: [messagePayloadKey: AnyMessageBox(value: message)])
    }

    public func messages<M: NotificationsAsyncMessage>(
        of type: M.Type,
        from subject: M.Subject? = nil
    ) -> AsyncCompactMapSequence<NotificationCenter.Notifications, M> {
        notifications(named: M.name, object: subject)
            .compactMap { note in
                (note.userInfo?[messagePayloadKey] as? AnyMessageBox)?.value as? M
            }
    }

    public func addObserver<M: NotificationsAsyncMessage>(
        of type: M.Type,
        from subject: M.Subject? = nil,
        using handler: @escaping @Sendable (M) -> Void
    ) -> NotificationsObservationToken {
        let token = addObserver(forName: M.name, object: subject, queue: nil) { note in
            guard let payload = (note.userInfo?[messagePayloadKey] as? AnyMessageBox)?.value as? M else { return }
            handler(payload)
        }
        return NotificationsObservationToken(token: token, center: self)
    }
}

// MARK: - NotificationCenter extensions: MainActorMessage

extension NotificationCenter {

    @MainActor
    public func post<M: NotificationsMainActorMessage>(_ message: M, subject: M.Subject? = nil) {
        post(name: M.name, object: subject, userInfo: [messagePayloadKey: AnyMessageBox(value: message)])
    }

    @MainActor
    public func messages<M: NotificationsMainActorMessage>(
        of type: M.Type,
        from subject: M.Subject? = nil
    ) -> AsyncCompactMapSequence<NotificationCenter.Notifications, M> {
        notifications(named: M.name, object: subject)
            .compactMap { note in
                (note.userInfo?[messagePayloadKey] as? AnyMessageBox)?.value as? M
            }
    }

    @MainActor
    public func addObserver<M: NotificationsMainActorMessage>(
        of type: M.Type,
        from subject: M.Subject? = nil,
        using handler: @escaping @MainActor (M) -> Void
    ) -> NotificationsObservationToken {
        let token = addObserver(forName: M.name, object: subject, queue: .main) { note in
            guard let payload = (note.userInfo?[messagePayloadKey] as? AnyMessageBox)?.value as? M else { return }
            MainActor.assumeIsolated {
                handler(payload)
            }
        }
        return NotificationsObservationToken(token: token, center: self)
    }
}
