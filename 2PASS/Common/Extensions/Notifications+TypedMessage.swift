// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import os

// MARK: - Typed-message backport of iOS 26's NotificationCenter.AsyncMessage / .MainActorMessage
//
// Same API shape (argument labels, method names) as the iOS 26 SDK so adoption today is
// identical to adoption tomorrow. Transport reuses `NotificationCenter`: the typed message
// is packed into `userInfo` under one private key; subject scoping reuses `object:`.

public enum Notifications {

    /// Typed multicast message that may cross actor boundaries. Backport of iOS 26's
    /// `NotificationCenter.AsyncMessage`.
    ///
    /// Posting is **synchronous**: observers registered via `addObserver(of:from:using:)`
    /// run before `post(_:subject:)` returns. `messages(of:from:)` consumers wake up later
    /// off-actor. The `Subject` is matched by pointer identity (non-retained), so a
    /// `subject` that deinits before delivery silently drops the message.
    public protocol AsyncMessage: Sendable {
        associatedtype Subject: AnyObject
        static var name: Notification.Name { get }
    }

    /// Main-actor-bound variant. Both posting and synchronous observation require
    /// `@MainActor` isolation. Backport of iOS 26's `NotificationCenter.MainActorMessage`.
    public protocol MainActorMessage {
        associatedtype Subject: AnyObject
        static var name: Notification.Name { get }
    }

    /// Element-typed concrete return type of `NotificationCenter.messages(of:)`. Spell as
    /// `Notifications.MessageSequence<M>` at call sites.
    public typealias MessageSequence<M> = AsyncCompactMapSequence<NotificationCenter.Notifications, M>

    /// RAII handle for `addObserver(of:from:using:)`. The underlying observer is removed
    /// on `deinit` or explicit `cancel()`, whichever comes first. Cancellation is idempotent.
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

/// Erased envelope that carries a `Sendable` payload through `userInfo: [AnyHashable: Any]?`.
/// The only `@unchecked Sendable` in the backport — public APIs only deposit `Sendable`
/// messages and only extract back to the original type, so the erasure window is narrow.
private struct AnyMessageBox: @unchecked Sendable {
    let value: Any
}

// MARK: - Module-scope public aliases
//
// Inside `extension NotificationCenter { ... }` the bare name `Notifications` resolves to
// Foundation's nested `NotificationCenter.Notifications` first. Single-token typealiases
// at module scope sidestep the dotted-path lookup. Call sites should still use
// `Notifications.AsyncMessage` etc. — these are extension-method internals.

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

    /// Synchronous observer. Handler runs on the poster's thread before `post(_:subject:)`
    /// returns — useful when the producer needs observer-driven side effects to have landed
    /// before continuing.
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

    /// Synchronous observer delivered on the main thread via `OperationQueue.main`. The
    /// `MainActor.assumeIsolated` bridge is safe because `OperationQueue.main` is pinned
    /// to the main thread.
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
