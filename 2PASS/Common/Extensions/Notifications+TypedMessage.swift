// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2026 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import Foundation
import os

// MARK: - Typed-message backport of iOS 26's NotificationCenter.AsyncMessage / .MainActorMessage
//
// Mirrors the iOS 26 SDK API shape so adoption today is identical to adoption tomorrow:
// when the deployment-target floor rises to iOS 26, the migration is "delete this file
// and search-and-replace `Notifications.AsyncMessage` → `NotificationCenter.AsyncMessage`."
// No call-site rewrites — the `subject:`, `from:`, `of:`, `using:` argument labels and the
// method names (`post`, `messages`, `addObserver`) match Apple's signatures.
//
// Transport reuses `NotificationCenter`: the typed message is packed into `userInfo` under
// a single private key, and subject scoping reuses the existing `object:` parameter (which
// has been pointer-identity-matched and non-retained since 1994 — same lifecycle as iOS 26's
// weakly-held `Subject`). The only `@unchecked Sendable` in the module is the private
// envelope that carries a `Sendable` payload through `[AnyHashable: Any]?` — concentrated
// in one place, never exposed to consumers.

public enum Notifications {

    /// Typed multicast message that may cross actor boundaries. Backport of
    /// `NotificationCenter.AsyncMessage` (iOS 26+).
    ///
    /// Conforming types are `Sendable` and identify themselves to subscribers via a static
    /// `Notification.Name`. The default `name` is derived from the fully-qualified type
    /// identity, so unrelated message types in different modules cannot collide; conformers
    /// can override it (`static let name = ...`) when they need a stable string — e.g. for
    /// cross-process notifications, which this codebase does not currently use.
    ///
    /// **Posting is synchronous** despite the protocol name. "Async" in `AsyncMessage` denotes
    /// that the payload is `Sendable` and may be observed across actors, not that
    /// `post(_:subject:)` suspends. Observers registered via `addObserver(of:from:using:)`
    /// run before `post(_:subject:)` returns; observers iterating `messages(of:from:)` wake
    /// up later off-actor.
    public protocol AsyncMessage: Sendable {
        /// Object whose identity scopes the message. `NotificationCenter` matches by pointer
        /// identity (non-retained), so a `subject` that deinits before delivery silently
        /// drops the message — same lifecycle as iOS 26's weakly-held `Subject`.
        associatedtype Subject: AnyObject
        static var name: Notification.Name { get }
    }

    /// Typed multicast message bound to the main actor. Backport of
    /// `NotificationCenter.MainActorMessage` (iOS 26+).
    ///
    /// Posting and synchronous observation both require `@MainActor` isolation. Async
    /// iteration via `messages(of:from:)` is also `@MainActor`-creation-isolated. Use this
    /// variant for events whose handlers always touch UI state.
    public protocol MainActorMessage {
        associatedtype Subject: AnyObject
        static var name: Notification.Name { get }
    }

    /// Element-typed concrete return type of `NotificationCenter.messages(of:)` — same
    /// shape for both the `AsyncMessage` and `MainActorMessage` overloads. Spell properties
    /// and parameters as `Notifications.MessageSequence<M>` instead of repeating
    /// `AsyncCompactMapSequence<NotificationCenter.Notifications, M>` at every call site.
    /// Same iOS-15 floor as the underlying `notifications(named:object:)`.
    public typealias MessageSequence<M> = AsyncCompactMapSequence<NotificationCenter.Notifications, M>

    /// RAII handle returned by `addObserver(of:from:using:)`. Backport of iOS 26's
    /// auto-cleanup-on-token-release semantics: the underlying `NotificationCenter` observer
    /// is removed on `deinit` or explicit `cancel()`, whichever comes first. Cancellation
    /// is idempotent.
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

/// Single `userInfo` key under which the typed message is carried. Private to this file;
/// consumers only see typed `Message` values via the public APIs below.
private let messagePayloadKey = "Notifications.payload"

/// Erased envelope that carries a `Sendable` payload through `userInfo: [AnyHashable: Any]?`.
/// This is the only `@unchecked Sendable` in the backport — the irreducible cost of going
/// through `NotificationCenter`'s untyped userInfo dictionary. Public APIs only deposit
/// `Sendable`-constrained messages and only extract back to the original type, so the
/// erasure window is narrow and never observable.
private struct AnyMessageBox: @unchecked Sendable {
    let value: Any
}

// MARK: - Module-scope public aliases (workaround for extension-scope name shadowing)
//
// Inside `extension NotificationCenter { ... }` the bare name `Notifications` resolves to
// `NotificationCenter.Notifications` (Foundation's nested `AsyncSequence` type) before our
// module-level `Notifications` enum, because Swift's lookup walks the inner scope first.
// Module-qualifying with `Common.Notifications` doesn't reliably resolve from inside the
// same module. The cleanest workaround is module-scope public aliases under single-token
// names: a single identifier doesn't trigger nested-scope dotted-path lookup, so the
// compiler resolves it directly to the typealias's right-hand side, which is itself
// resolved here at module scope where `Notifications` unambiguously means our enum.
//
// Call sites should always use `Notifications.AsyncMessage` etc. — these aliases are
// implementation detail of the extension methods below and not the canonical public form.

/// Implementation alias used by the `NotificationCenter` extensions in this file.
/// **Prefer `Notifications.AsyncMessage` at call sites.**
public typealias NotificationsAsyncMessage = Notifications.AsyncMessage

/// Implementation alias used by the `NotificationCenter` extensions in this file.
/// **Prefer `Notifications.MainActorMessage` at call sites.**
public typealias NotificationsMainActorMessage = Notifications.MainActorMessage

/// Implementation alias used by the `NotificationCenter` extensions in this file.
/// **Prefer `Notifications.ObservationToken` at call sites.**
public typealias NotificationsObservationToken = Notifications.ObservationToken

// MARK: - NotificationCenter extensions: AsyncMessage

extension NotificationCenter {

    /// Posts a typed message to every observer registered for `M` (optionally filtered by
    /// `subject` identity). Synchronous fan-out: `addObserver(of:)`-registered handlers run
    /// before this returns; `messages(of:)`-iterating consumers wake up later off-actor.
    public func post<M: NotificationsAsyncMessage>(_ message: M, subject: M.Subject? = nil) {
        post(name: M.name, object: subject, userInfo: [messagePayloadKey: AnyMessageBox(value: message)])
    }

    /// Async sequence of messages of type `M`, optionally filtered by `subject` identity.
    /// Each call returns a fresh sequence; multiple iterators receive every posted message
    /// in parallel (`NotificationCenter` already does multicast).
    public func messages<M: NotificationsAsyncMessage>(
        of type: M.Type,
        from subject: M.Subject? = nil
    ) -> AsyncCompactMapSequence<NotificationCenter.Notifications, M> {
        notifications(named: M.name, object: subject)
            .compactMap { note in
                (note.userInfo?[messagePayloadKey] as? AnyMessageBox)?.value as? M
            }
    }

    /// Registers a synchronous observer for messages of type `M`. The handler runs on the
    /// poster's thread before `post(_:subject:)` returns — useful when the producer needs to
    /// rely on observer-driven side effects having landed before continuing. Returns a
    /// token that auto-removes the observer on `deinit` or explicit `cancel()`.
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

    /// `@MainActor`-isolated post of a main-actor-bound message. Observers also receive on
    /// main actor — `addObserver(of:)` handlers run synchronously on `OperationQueue.main`,
    /// `messages(of:)` consumers iterate from `@MainActor` context.
    @MainActor
    public func post<M: NotificationsMainActorMessage>(_ message: M, subject: M.Subject? = nil) {
        post(name: M.name, object: subject, userInfo: [messagePayloadKey: AnyMessageBox(value: message)])
    }

    /// `@MainActor`-isolated async sequence of messages of type `M`. Creation is bound to
    /// the main actor; iteration runs there as well because `MainActorMessage` payloads are
    /// only ever posted from main actor.
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

    /// `@MainActor`-isolated synchronous observer. The handler is delivered on the main
    /// thread (via `OperationQueue.main`) and bridged into `@MainActor` isolation through
    /// `MainActor.assumeIsolated`, which is safe here because `OperationQueue.main` is
    /// pinned to the main thread.
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
