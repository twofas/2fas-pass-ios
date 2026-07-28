// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import Common

struct SettingsView: View {
    
    @State
    var presenter: SettingsPresenter

    /// Drives the split detail column's stack so detail sections push onto one shared path.
    @State
    private var detailPath = NavigationPath()

    @Environment(\.openURL)
    private var openURL

    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass

    /// When false, the view always uses the plain navigation stack regardless of width. The iPad
    /// tab-bar layout ("middle" size) passes false so Settings pushes with a simple navigation bar
    /// instead of a side-by-side split; the iPad modal leaves it true to keep the two-column split.
    var usesSplitLayout = true

    var onCloseHandler: (() -> Void)?

    var body: some View {
        Group {
            // Use the two-column split only at regular width (e.g. the iPad modal). In compact width
            // — and wherever the split is disabled — fall back to the stack, whose `.router` actually
            // pushes; the split's detail column doesn't navigate when collapsed.
            if usesSplitLayout, horizontalSizeClass == .regular {
                splitBody
            } else {
                stackBody
            }
        }
    }

    private var stackBody: some View {
        NavigationStack {
            formList
                .router(router: SettingsRouter(), destination: $presenter.destination)
                .navigationTitle(.settingsTitle)
                .toolbar { closeToolbar }
        }
    }

    private var splitBody: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            formList
                .scrollContentBackground(.hidden)
                .background(Color(.systemGroupedBackground))
                .navigationTitle(.settingsTitle)
                .toolbar { closeToolbar }
                .toolbar(removing: .sidebarToggle)
                .navigationSplitViewColumnWidth(360)
        } detail: {
            NavigationStack(path: $detailPath) {
                if let destination = presenter.destination {
                    SettingsRouter().view(for: destination)
                }
            }
            // Share this stack's path so detail sections push onto one path instead of
            // spinning up their own nested stacks via the isPresented fallback.
            .useNavigationPath($detailPath)
        }
        .onChange(of: presenter.destination) { _, _ in
            // Switching sidebar entries swaps the stack root, so pop any deeper pushes
            // back to root. Clearing the path keeps the stack's identity (cheaper than
            // re-creating it via `.id`) while still resetting to the new section.
            // No animation: the root is swapping anyway, so an animated pop would just
            // add a stray slide on top of the section change. `animation: nil` alone
            // isn't enough — NavigationStack still runs its own default pop animation,
            // so hard-disable animations for this transaction.
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                detailPath = NavigationPath()
            }
        }
        .onAppear {
            // Pre-select the first row so the detail column isn't empty when Settings opens on iPad.
            if presenter.destination == nil {
                presenter.destination = .security
            }
        }
    }

    /// True when `destination` is the one currently shown in the split's detail column (regular width).
    /// Compact layouts push the detail (no persistent selection), so the row highlight is suppressed.
    private func isSelectedDetail(_ destination: SettingsDestination) -> Bool {
        usesSplitLayout
            && horizontalSizeClass == .regular
            && presenter.destination == destination
    }

    @ToolbarContentBuilder
    private var closeToolbar: some ToolbarContent {
        if let onCloseHandler {
            ToolbarCancelItem(action: onCloseHandler)
        }
    }

    private var formList: some View {
        Form {
            Section {
                Button {
                    presenter.onSecurity()
                } label: {
                    SettingsRowView(
                        icon: .lock,
                        title: .settingsEntrySecurity
                    )
                }
                .settingsRowSelected(isSelectedDetail(.security))
                
                Button {
                    presenter.onCustomization()
                } label: {
                    SettingsRowView(
                        icon: .customization,
                        title: .settingsEntryCustomization
                    )
                }
                .settingsRowSelected(isSelectedDetail(.customization))
                
                Button {
                    presenter.onAutoFill()
                } label: {
                    SettingsRowView(
                        icon: .autofill,
                        title: .settingsEntryAutofill,
                        additionalInfo: Text(presenter.autoFillStatus)
                    )
                }
                .settingsRowSelected(isSelectedDetail(.autoFill))
                
                Button {
                    presenter.onDeletedData()
                } label: {
                    SettingsRowView(
                        icon: .deletedData,
                        title: .settingsEntryTrash
                    )
                }
                .settingsRowSelected(isSelectedDetail(.deletedData))
            } header: {
                Text(.settingsHeaderMobileApp)
                    .padding(.top, Spacing.xll)
            }
            
            Section(.settingsHeaderBrowserExtension) {
                Button {
                    presenter.onKnownWebBrowsers()
                } label: {
                    SettingsRowView(
                        icon: .knownWebBrowsers,
                        title: .settingsEntryKnownBrowsers
                    )
                }
                .settingsRowSelected(isSelectedDetail(.knownWebBrowsers))
                
                Button {
                    presenter.onPushNotifications()
                } label: {
                    SettingsRowView(
                        icon: .pushNotifications,
                        title: .settingsEntryPushNotifications,
                        additionalInfo: Text(presenter.pushNotificationsStatus)
                    )
                }
                .settingsRowSelected(isSelectedDetail(.pushNotifications))
            }
            
            Section(.settingsHeaderBackup) {
                Button {
                    presenter.onSync()
                } label: {
                    SettingsRowView(
                        icon: .sync,
                        title: .settingsEntryCloudSync,
                        additionalInfo: {
                            if presenter.hasSyncError {
                                BadgeView(value: 1)
                            } else {
                                Text(presenter.syncStatus)
                            }
                        }
                    )
                }
                .settingsRowSelected(isSelectedDetail(.sync))
                
                Button {
                    presenter.onImportExport()
                } label: {
                    SettingsRowView(
                        icon: .importExport,
                        title: .settingsEntryImportExport
                    )
                }
                .settingsRowSelected(isSelectedDetail(.importExport))
                
                Button {
                    presenter.onTransferItems()
                } label: {
                    SettingsRowView(
                        icon: .transferItems,
                        title: .settingsEntryTransferFromOtherApps
                    )
                }
                .settingsRowSelected(isSelectedDetail(.transferItems))
            }
            
            Section(.settingsManageTokensTitle) {
                Button {
                    if presenter.is2FASAuthInstalled {
                        openURL(Config.twofasAuthOpenLink)
                    } else {
                        openURL(Config.twofasAuthAppStoreLink)
                    }
                } label: {
                    SettingsRowView(
                        icon: .twoFASAuth,
                        title: presenter.is2FASAuthInstalled ? .settings2FasOpen : .settings2FasGet,
                        actionIcon: .link
                    )
                }
                .settingsRowDefaultBackground()
            }
            
            Section(.settingsHeaderAbout) {
                if presenter.isPaidUser {
                    Button {
                        presenter.onSubscription()
                    } label: {
                        SettingsRowView(
                            icon: .subscription,
                            title: .settingsEntrySubscription,
                            actionIcon: .chevron,
                            additionalInfo: Text(presenter.subscriptionStatus)
                        )
                    }
                    .settingsRowSelected(isSelectedDetail(.manageSubscription))
                } else {
                    Button {
                        presenter.onSubscription()
                    } label: {
                        SettingsRowView(
                            icon: .subscription,
                            title: .settingsEntrySubscription,
                            actionIcon: .chevron,
                            additionalInfo: Text(presenter.subscriptionStatus)
                        )
                    }
                    .settingsRowSelected(isSelectedDetail(.manageSubscription))
                }
                
                Button {
                    presenter.onAbout()
                } label: {
                    SettingsRowView(
                        icon: .about,
                        title: .settingsEntryAbout
                    )
                }
                .settingsRowSelected(isSelectedDetail(.about))
                
                Button {
                    openURL(URL(string: "https://2fas.com/help-center/")!)
                } label: {
                    SettingsRowView(
                        icon: .help,
                        title: .settingsEntryHelpCenter,
                        actionIcon: .link
                    )
                }
                .settingsRowDefaultBackground()
                
                Button {
                    openURL(URL(string: "https://2fas.com/discord")!)
                } label: {
                    SettingsRowView(
                        icon: .discord,
                        title: .settingsEntryDiscord,
                        actionIcon: .link
                    )
                }
                .settingsRowDefaultBackground()
            }
            
#if PROD
#else
            Section {
                Button {
                    presenter.onDebug()
                } label: {
                    SettingsRowView(
                        icon: .debug,
                        title: Text("Debug" as String)
                    )
                }
                .settingsRowSelected(isSelectedDetail(.debug))
            }
#endif
        }
        .onAppear {
            presenter.onAppear()
        }
        .task {
            await presenter.observeAutoFillStatusChanged()
        }
        .task {
            await presenter.observePushNotificationsStatusChanged()
        }
        .task {
            await presenter.observeSyncErrorChanges()
        }
        .task {
            await presenter.observeSyncEnabledChanges()
        }
    }

    func onClose(_ handler: (() -> Void)?) -> Self {
        var instance = self
        instance.onCloseHandler = handler
        return instance
    }
}

private extension View {

    /// Highlights a settings row as the selected detail (split layout). The same `neutral100` fill is
    /// used for the pressed (highlighted) state so a tap matches the persistent selection color.
    func settingsRowSelected(_ isSelected: Bool) -> some View {
        modifier(SettingsRowHighlight(isSelected: isSelected))
    }

    /// Explicit default cell background for rows that never show as the selected detail (external
    /// links). Needed for the same reason `SettingsRowHighlight` pins its unselected background:
    /// the split sidebar inside a sheet otherwise resolves rows to a near-invisible material in
    /// light mode on iOS 26.
    func settingsRowDefaultBackground() -> some View {
        listRowBackground(SettingsRowHighlight.defaultBackground)
    }
}

/// Paints both the pressed and selected backgrounds with the same highlight fill so the color shown
/// while tapping matches the selected-detail color in the split layout. The fill tracks the system
/// list highlight per appearance — `neutral200` in light mode, the lighter `neutral300` in dark mode.
/// The button's pressed state is bubbled up through a preference because `listRowBackground` only
/// takes effect at the row level, not from inside a `ButtonStyle`.
private struct SettingsRowHighlight: ViewModifier {
    let isSelected: Bool

    @State private var isPressed = false

    private static let highlightColor = Color(UIColor(light: .neutral200, dark: .neutral300))

    /// Explicit stand-in for the default grouped cell background. Leaving the unselected branch `nil`
    /// keeps the system default, which the iOS 26 split sidebar resolves to a near-invisible material
    /// when the split sits in a sheet (light mode).
    static let defaultBackground = Color(.secondarySystemGroupedBackground)

    func body(content: Content) -> some View {
        content
            .buttonStyle(PressTrackingButtonStyle())
            .onPreferenceChange(PressedPreferenceKey.self) { isPressed = $0 }
            .listRowBackground((isSelected || isPressed) ? Self.highlightColor : Self.defaultBackground)
    }
}

private struct PressedPreferenceKey: PreferenceKey {
    static let defaultValue = false

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

private struct PressTrackingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .preference(key: PressedPreferenceKey.self, value: configuration.isPressed)
    }
}

#Preview {
    SettingsRouter.buildView()
}
