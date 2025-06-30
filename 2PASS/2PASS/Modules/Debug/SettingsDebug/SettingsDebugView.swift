// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI
import RevenueCat
import Common

struct SettingsDebugView: View {
    
    @AppStorage(DebugOverlay.enablingKey)
    private var isDebugOverlayEnabled = false
    
    @State var presenter: SettingsDebugPresenter
    
    @State private var debugPaymentsVisible = false
    
    var body: some View {
        SettingsDetailsForm(Text("Debug" as String)) {
            Section {
                LabeledContent("Version" as String, value: presenter.version)
            }
            
            Section {
                Button {
                    presenter.onEventLog()
                } label: {
                    SettingsRowView(
                        icon: .eventLog,
                        title: Text("Event Log" as String)
                    )
                }
                
                Button {
                    presenter.onAppState()
                } label: {
                    SettingsRowView(
                        icon: .appState,
                        title: Text("App State" as String)
                    )
                }
                
                Button {
                    presenter.onGeneratePasswords()
                } label: {
                    SettingsRowView(
                        icon: .generate,
                        title: Text("Generate Passwords" as String)
                    )
                }
                
                Button {
                    presenter.onModifyState()
                } label: {
                    SettingsRowView(
                        icon: .modifyState,
                        title: Text("Modify State" as String)
                    )
                }
                
                #if DEBUG
                Button {
                    debugPaymentsVisible = true
                } label: {
                    SettingsRowView(
                        icon: .paymentsDebug,
                        title: Text("Payments Debug" as String)
                    )
                }
                #endif
                
                Picker(selection: $presenter.debugSubscriptionPlanType) {
                    Text("None" as String)
                        .tag(SubscriptionPlanType?.none)
                    
                    ForEach(SubscriptionPlanType.allCases, id: \.self) { plan in
                        Text(plan.rawValue.capitalized)
                            .tag(SubscriptionPlanType?.some(plan))
                    }
                } label: {
                    SettingsRowView(
                        icon: .debug,
                        title: Text("Override Premium Plan" as String),
                        actionIcon: nil
                    )
                }
                .pickerStyle(.navigationLink)
                
                Toggle(isOn: $isDebugOverlayEnabled) {
                    SettingsRowView(
                        icon: .debug,
                        title: Text("Enable Debug Overlay" as String),
                        actionIcon: nil
                    )
                }
                .onChange(of: isDebugOverlayEnabled) { _, _ in
                    NotificationCenter.default.post(name: .debugOverlayStateChange, object: nil)
                }
            }
        }
        .router(router: SettingsDebugRouter(), destination: $presenter.destination)
        #if DEBUG
        .debugRevenueCatOverlay(isPresented: $debugPaymentsVisible)
        #endif
    }
}

#Preview {
    SettingsDebugRouter.buildView()
}
