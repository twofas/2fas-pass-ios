// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import UniformTypeIdentifiers

public enum FileImportResult {
    case cantReadFile
    case fileOpen(URL)
    case cancelled
}

public enum RoutingType: Equatable {
    case push
    case sheet
    case actionSheet(title: String)
    case fullScreenCover
    case slidePush
    case alert(title: String, message: String?)
    case fileImporter(contentTypes: [UTType], onClose: (FileImportResult) -> Void)

    public static func == (lhs: RoutingType, rhs: RoutingType) -> Bool {
        switch (lhs, rhs) {
        case (.push, .push),
            (.sheet, .sheet),
            (.fileImporter, .fileImporter),
            (.fullScreenCover, .fullScreenCover),
            (.slidePush, .slidePush):
            return true

        case let (.actionSheet(title1), .actionSheet(title2)):
            return title1 == title2

        case let (.alert(title1, message1), .alert(title2, message2)):
            return title1 == title2 && message1 == message2

        default:
            return false
        }
    }
}

public protocol Router {
    associatedtype Destination: Identifiable
    associatedtype DestinationView: View

    @MainActor @ViewBuilder
    func view(for destination: Destination) -> DestinationView
    func routingType(for destination: Destination?) -> RoutingType? // TODO: Remove optionals
}

public protocol RouterDestination: Identifiable, Hashable {}

public extension RouterDestination {

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

public extension RouterDestination where ID == String {

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.id == rhs.id
    }
}

public extension RouterDestination where ID == Self {

    var id: Self {
        self
    }
}

struct RoutingModifier<R: Router>: ViewModifier {

    private enum ModalChannel {
        case sheet
        case fullScreenCover
    }

    let router: R
    @Binding var destination: R.Destination?

    // Per-channel latched copies of `destination`. Presentation is driven by these, so a
    // dismiss callback arriving after `destination` already moved to another channel can
    // only clear its own latch — never the new destination.
    @State private var sheetItem: R.Destination?
    @State private var fullScreenCoverItem: R.Destination?
    @State private var slidePushItem: R.Destination?
    @State private var alertItem: R.Destination?
    @State private var fileImporterItem: R.Destination?

    // Channels whose content is on screen; a channel latched to nil but still present here
    // is mid-dismissal, and new modal presentation waits for its `onDismiss`.
    @State private var presentedModals: Set<ModalChannel> = []

    func body(content: Content) -> some View {
        content
            .sheet(item: sheetBinding, onDismiss: { completeDismissal(of: .sheet) }) { item in
                // A sheet is a separate presentation context: a push appended to the presenter's
                // shared path (`useNavigationPath`) would render behind the sheet, never inside it.
                // Clear the inherited path so presented content always starts with fresh navigation;
                // a `useNavigationPath` set inside the sheet still wins, being deeper in the hierarchy.
                router.view(for: liveValue(for: item))
                    .environment(\.navigationPath, nil)
                    .onAppear {
                        presentedModals.insert(.sheet)
                    }
            }
            .slideNavigationDestination(isPresented: slidePushBinding) {
                if let slidePushItem {
                    router.view(for: liveValue(for: slidePushItem))
                }
            }
            .fullScreenCover(item: fullScreenCoverBinding, onDismiss: { completeDismissal(of: .fullScreenCover) }) { item in
                router.view(for: liveValue(for: item))
                    .environment(\.navigationPath, nil)
                    .onAppear {
                        presentedModals.insert(.fullScreenCover)
                    }
            }
            .fileImporter(
                isPresented: fileImporterBinding,
                allowedContentTypes: fileImporterConfiguration?.contentTypes ?? [],
                allowsMultipleSelection: false,
                onCompletion: fileImporterOnCompletion,
                onCancellation: fileImporterOnCancellation
            )
            .background {
                EmptyView()
                    .alert(alertConfiguration?.title ?? "", isPresented: alertBinding, actions: {
                        if let alertItem {
                            router.view(for: liveValue(for: alertItem))
                        }
                    }, message: {
                        if let message = alertConfiguration?.message {
                            Text(verbatim: message)
                        }
                    })
                    .tint(nil)
            }
            .onChange(of: destination?.id, initial: true) {
                sync()
            }
    }

    // MARK: - Destination distribution

    private func sync() {
        let target = destination.flatMap { router.routingType(for: $0) }

        if sheetItem != nil, target != .sheet {
            sheetItem = nil
        }
        if fullScreenCoverItem != nil, target != .fullScreenCover {
            fullScreenCoverItem = nil
        }
        if slidePushItem != nil, target != .slidePush {
            slidePushItem = nil
        }
        if alertItem != nil, isAlert(target) == false {
            alertItem = nil
        }
        if fileImporterItem != nil, isFileImporter(target) == false {
            fileImporterItem = nil
        }

        guard let destination, let target else { return }

        if isModal(target), hasDismissalInFlight {
            // UIKit can't present a modal while another one is animating out;
            // that channel's `onDismiss` re-runs `sync()` and presents this destination.
            return
        }

        switch target {
        case .sheet:
            sheetItem = destination
        case .fullScreenCover:
            fullScreenCoverItem = destination
        case .alert:
            alertItem = destination
        case .fileImporter:
            fileImporterItem = destination
        case .slidePush:
            slidePushItem = destination
        case .push, .actionSheet:
            break
        }
    }

    private var hasDismissalInFlight: Bool {
        (presentedModals.contains(.sheet) && sheetItem == nil)
            || (presentedModals.contains(.fullScreenCover) && fullScreenCoverItem == nil)
    }

    private func completeDismissal(of channel: ModalChannel) {
        presentedModals.remove(channel)
        sync()
    }

    private func clearDestination(afterDismissing dismissed: R.Destination) {
        if let destination, destination.id == dismissed.id {
            self.destination = nil
        }
    }

    // Prefer the live destination so a re-set value with the same id (fresh closures)
    // reaches the presented view; fall back to the latch while a dismissal animates.
    private func liveValue(for item: R.Destination) -> R.Destination {
        if let destination, destination.id == item.id {
            return destination
        }
        return item
    }

    private func isModal(_ type: RoutingType) -> Bool {
        switch type {
        case .sheet, .fullScreenCover, .alert, .fileImporter:
            return true
        case .push, .slidePush, .actionSheet:
            return false
        }
    }

    private func isAlert(_ type: RoutingType?) -> Bool {
        guard let type, case .alert = type else {
            return false
        }
        return true
    }

    private func isFileImporter(_ type: RoutingType?) -> Bool {
        guard let type, case .fileImporter = type else {
            return false
        }
        return true
    }

    // MARK: - Channel bindings

    private var sheetBinding: Binding<R.Destination?> {
        Binding(
            get: { sheetItem },
            set: { newValue in
                guard newValue == nil, let dismissed = sheetItem else { return }
                sheetItem = nil
                clearDestination(afterDismissing: dismissed)
            }
        )
    }

    private var fullScreenCoverBinding: Binding<R.Destination?> {
        Binding(
            get: { fullScreenCoverItem },
            set: { newValue in
                guard newValue == nil, let dismissed = fullScreenCoverItem else { return }
                fullScreenCoverItem = nil
                clearDestination(afterDismissing: dismissed)
            }
        )
    }

    private var slidePushBinding: Binding<Bool> {
        Binding(
            get: { slidePushItem != nil },
            set: { isPresented in
                guard isPresented == false, let dismissed = slidePushItem else { return }
                slidePushItem = nil
                clearDestination(afterDismissing: dismissed)
            }
        )
    }

    private var alertBinding: Binding<Bool> {
        Binding(
            get: { alertItem != nil },
            set: { isPresented in
                guard isPresented == false, let dismissed = alertItem else { return }
                alertItem = nil
                clearDestination(afterDismissing: dismissed)
            }
        )
    }

    private var fileImporterBinding: Binding<Bool> {
        Binding(
            get: { fileImporterItem != nil },
            set: { isPresented in
                guard isPresented == false, let dismissed = fileImporterItem else { return }
                fileImporterItem = nil
                clearDestination(afterDismissing: dismissed)
            }
        )
    }

    // MARK: - Alert / file importer configuration

    private var alertConfiguration: (title: String, message: String?)? {
        guard let alertItem, case let .alert(title, message) = router.routingType(for: alertItem) else {
            return nil
        }
        return (title, message)
    }

    private var fileImporterConfiguration: (contentTypes: [UTType], onClose: (FileImportResult) -> Void)? {
        guard let fileImporterItem, case let .fileImporter(contentTypes, onClose) = router.routingType(for: fileImporterItem) else {
            return nil
        }
        return (contentTypes, onClose)
    }

    private var fileImporterOnCompletion: (Result<[URL], Error>) -> Void {
        guard let onClose = fileImporterConfiguration?.onClose else {
            return { _ in }
        }
        return { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else {
                    onClose(.cantReadFile)
                    return
                }
                onClose(.fileOpen(url))
            case .failure:
                onClose(.cantReadFile)
            }
        }
    }

    private var fileImporterOnCancellation: () -> Void {
        guard let onClose = fileImporterConfiguration?.onClose else {
            return {}
        }
        return {
            onClose(.cancelled)
        }
    }
}

extension View {

    public func router<R: Router>(router: R, destination: Binding<R.Destination?>) -> some View {
        modifier(RoutingModifier(router: router, destination: destination))
            .modifier(RoutingNavigationStackByItemModifier(router: router, destination: destination))
    }

    public func router<R: Router>(router: R, destination: Binding<R.Destination?>) -> some View where R.Destination: Hashable {
        modifier(RoutingModifier(router: router, destination: destination))
            .modifier(RoutingNavigationStackModifier(router: router, destination: destination))
    }

    public func router<R: Router>(router: R, destination: Binding<R.Destination?>, navigationPath: Binding<NavigationPath>) -> some View where R.Destination: Hashable {
        modifier(RoutingModifier(router: router, destination: destination))
            .modifier(RoutingNavigationStackByPathModifier(router: router, destination: destination, navigationPath: navigationPath))
    }

    public func useNavigationPath(_ path: Binding<NavigationPath>) -> some View {
        environment(\.navigationPath, path)
    }
}

private struct RoutingNavigationStackModifier<R: Router>: ViewModifier where R.Destination: Hashable {

    let router: R
    @Binding var destination: R.Destination?

    @Environment(\.navigationPath) private var navigationPath

    func body(content: Content) -> some View {
        if let navigationPath {
            content
                .modifier(RoutingNavigationStackByPathModifier(router: router, destination: $destination, navigationPath: navigationPath))
        } else {
            content
                .modifier(RoutingNavigationStackByItemModifier(router: router, destination: $destination))
        }
    }
}

private struct RoutingNavigationStackByPathModifier<R: Router>: ViewModifier where R.Destination: Hashable {

    let router: R

    @Binding var destination: R.Destination?
    @Binding var navigationPath: NavigationPath

    @State private var previousPathCount: Int = 0

    func body(content: Content) -> some View {
        content
            .navigationDestination(for: R.Destination.self, destination: { destination in
                router.view(for: destination)
            })
            .onChange(of: navigationPath, { oldValue, newValue in
                if newValue.count <= previousPathCount,
                   let destination, router.routingType(for: destination) == .push {
                    self.destination = nil
                }
            })
            .onChange(of: destination) { oldValue, newValue in
                if let newValue, router.routingType(for: newValue) == .push {
                    previousPathCount = navigationPath.count
                    navigationPath.append(newValue)
                } else if newValue == nil, navigationPath.count > previousPathCount {
                    // Clearing `destination` programmatically must pop the pushed screen. Unlike
                    // `navigationDestination(isPresented:)` (used by the item-based modifier), a
                    // NavigationPath doesn't unwind on its own — remove the entries appended since
                    // the push so a shared-path detail (iPad Settings split) returns to its root.
                    navigationPath.removeLast(navigationPath.count - previousPathCount)
                }
            }
    }
}

private struct RoutingNavigationStackByItemModifier<R: Router>: ViewModifier {

    let router: R
    @Binding var destination: R.Destination?

    // Keeps the pushed view's content stable while a pop animates after `destination`
    // was cleared or re-routed to another channel.
    @State private var pushedItem: R.Destination?

    private var pushDestinationProxy: Binding<Bool> {
        Binding<Bool>(
            get: {
                guard let destination else {
                    return false
                }
                return router.routingType(for: destination) == .push
            },
            set: {
                guard $0 == false else { return }
                if let destination, router.routingType(for: destination) == .push {
                    self.destination = nil
                }
            }
        )
    }

    func body(content: Content) -> some View {
        content
            .navigationDestination(isPresented: pushDestinationProxy, destination: {
                if let item = currentPushValue {
                    router.view(for: item)
                }
            })
            .onChange(of: destination?.id, initial: true) {
                if let destination, router.routingType(for: destination) == .push {
                    pushedItem = destination
                }
            }
    }

    private var currentPushValue: R.Destination? {
        if let destination, router.routingType(for: destination) == .push {
            return destination
        }
        return pushedItem
    }
}

private struct NavigationPathEnvironmentKey: EnvironmentKey {
    static let defaultValue: Binding<NavigationPath>? = nil
}

private extension EnvironmentValues {

    var navigationPath: Binding<NavigationPath>? {
        get {
            self[NavigationPathEnvironmentKey.self]
        } set {
            self[NavigationPathEnvironmentKey.self] = newValue
        }
    }
}
