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
    
    let router: R
    @Binding var destination: R.Destination?
        
    private var sheetDestinationProxy: Binding<R.Destination?> {
        Binding<R.Destination?>(
            get: {
                if let destination, router.routingType(for: destination) == .sheet {
                    return destination
                } else {
                    return nil
                }
            },
            set: { destination in
                self.destination = destination
            }
        )
    }
    
    private var slidePushDestinationProxy: Binding<Bool> {
        Binding<Bool>(
            get: {
                guard let destination else {
                    return false
                }
                return router.routingType(for: destination) == .slidePush
            },
            set: {
                guard $0 == false else { return }
                self.destination = nil
            }
        )
    }
        
    private var fullScreenCoverProxy: Binding<Bool> {
        Binding<Bool>(
            get: {
                guard let destination else {
                    return false
                }
                return router.routingType(for: destination) == .fullScreenCover
            },
            set: {
                guard $0 == false else { return }
                self.destination = nil
            }
        )
    }
    
    private var alertProxy: Binding<Bool> {
        Binding<Bool>(
            get: {
                guard let destination else {
                    return false
                }
                if case .alert = router.routingType(for: destination) {
                    return true
                } else {
                    return false
                }
            },
            set: {
                guard $0 == false else { return }
                self.destination = nil
            }
        )
    }
    
    private var alertTitle: String? {
        guard let destination else {
            return nil
        }
        guard case let .alert(title, _) = router.routingType(for: destination) else {
            return nil
        }
        
        return title
    }
    
    private var alertMessage: String? {
        guard let destination else {
            return nil
        }
        guard case let .alert(_, message) = router.routingType(for: destination) else {
            return nil
        }
        
        return message
    }
    
    private var actionSheetProxy: Binding<Bool> {
        Binding<Bool>(
            get: {
                guard let destination else {
                    return false
                }
                if case .actionSheet = router.routingType(for: destination) {
                    return true
                } else {
                    return false
                }
            },
            set: {
                guard $0 == false else { return }
                self.destination = nil
            }
        )
    }
    
    private var actionSheetTitle: String? {
        guard let destination, case let .actionSheet(title) = router.routingType(for: destination) else {
            return nil
        }
        
        return title
    }
    
    private var fileImporterProxy: Binding<Bool> {
        Binding<Bool>(
            get: {
                guard let destination else {
                    return false
                }
                if case .fileImporter = router.routingType(for: destination) {
                    return true
                } else {
                    return false
                }
            },
            set: {
                guard $0 == false else { return }
                self.destination = nil
            }
        )
    }
    
    private var fileImportOpenTypes: [UTType] {
        guard let destination, case let .fileImporter(types, _) = router.routingType(for: destination) else {
            return []
        }
        
        return types
    }
    
    private var fileImportOnCompletion: (Result<[URL], Error>) -> Void {
        guard let destination, case let .fileImporter(_, onClose) = router.routingType(for: destination) else {
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
    
    private var fileImportOnCancellation: () -> Void {
        guard let destination, case let .fileImporter(_, onClose) = router.routingType(for: destination) else {
            return {}
        }
        
        return {
            onClose(.cancelled)
        }
    }
        
    func body(content: Content) -> some View {
        content
            .sheet(item: sheetDestinationProxy) { _ in
                router.view(for: destination!)
            }
            .slideNavigationDestination(isPresented: slidePushDestinationProxy) {
                if let activeNavigation = destination, case .slidePush = router.routingType(for: activeNavigation) {
                    router.view(for: activeNavigation)
                }
            }
            .fullScreenCover(isPresented: fullScreenCoverProxy) {
                router.view(for: destination!)
            }
            .alert(alertTitle ?? "", isPresented: alertProxy, actions: {
                if let activeNavigation = destination, case .alert = router.routingType(for: activeNavigation) {
                    router.view(for: activeNavigation)
                }
            }, message: {
                if let alertMessage {
                    Text(verbatim: alertMessage)
                }
            })
            .fileImporter(
                isPresented: fileImporterProxy,
                allowedContentTypes: fileImportOpenTypes,
                allowsMultipleSelection: false,
                onCompletion: fileImportOnCompletion,
                onCancellation: fileImportOnCancellation
            )
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
                if newValue.count <= previousPathCount {
                    destination = nil
                }
            })
            .onChange(of: destination) { oldValue, newValue in
                if let newValue, router.routingType(for: newValue) == .push {
                    previousPathCount = navigationPath.count
                    navigationPath.append(newValue)
                }
            }
    }
}

private struct RoutingNavigationStackByItemModifier<R: Router>: ViewModifier {
    
    let router: R
    @Binding var destination: R.Destination?
    
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
                self.destination = nil
            }
        )
    }
    
    func body(content: Content) -> some View {
        content
            .navigationDestination(isPresented: pushDestinationProxy, destination: {
                if let activeNavigation = destination, case .push = router.routingType(for: activeNavigation) {
                    router.view(for: activeNavigation)
                }
            })
    }
}

private struct NavigationPathEnvironemntKey: EnvironmentKey {
    static let defaultValue: Binding<NavigationPath>? = nil
}

private extension EnvironmentValues {
    
    var navigationPath: Binding<NavigationPath>? {
        get {
            self[NavigationPathEnvironemntKey.self]
        } set {
            self[NavigationPathEnvironemntKey.self] = newValue
        }
    }
}
