// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

private struct Constants {
    static let selectIconPickerCheckmarkSize: CGFloat = 18
    static let selectIconPickerMaxWidth: CGFloat = 340
    static let selectIconPickerVerticalPadding: CGFloat = 28
    
    static let labelSettingsMinWidthLabels: CGFloat = 80
}

struct CustomizeIconView: View {
    
    @State
    var presenter: CustomizeIconPresenter
    
    @State
    private var fieldWidth: CGFloat?
    
    @State
    private var currentColor: Color = .brand500
    
    @State
    private var selectedIconType: CustomizeIconType = .icon
    
    var body: some View {
        Form {
            Section(.customizeIconHeader) {
                HStack {
                    Spacer(minLength: 0)
                    selectIconPicker
                    Spacer(minLength: 0)
                }
                .listRowInsets(EdgeInsets(top: Constants.selectIconPickerVerticalPadding, leading: 0, bottom: Constants.selectIconPickerVerticalPadding, trailing: 0))
            }
            
            switch presenter.iconType {
            case .label:
                showLabel()
            case .icon:
                showIcon()
            case .custom:
                showCustom()
            }
        }
        .onChange(of: presenter.labelTitle) { oldValue, newValue in
            presenter.onLabelTitleChange(oldValue: oldValue, newValue: newValue)
        }
        .onChange(of: currentColor) { oldValue, newValue in
            presenter.labelColor = UIColor(newValue)
        }
        .onAppear {
            if let labelColor = presenter.labelColor {
                currentColor = Color(labelColor)
            }
            presenter.onAppear()
        }
    }
    
    private var selectIconPicker: some View {
        HStack {
            ForEach(CustomizeIconType.allCases, id: \.self) { iconType in
                Button {
                    presenter.onIconTypeChange(iconType)
                } label: {
                    VStack(spacing: Spacing.xs) {
                        switch iconType {
                        case .icon:
                            IconRendererView(content: presenter.domainIconContent)
                        case .label:
                            IconRendererView(content: presenter.labelIconContent)
                        case .custom:
                            IconRendererView(content: presenter.customIconContent)
                        }
                        
                        Text(iconType.label)
                            .font(.subheadline)
                            .foregroundStyle(Color.neutral950)
                        
                        Circle()
                            .stroke(lineWidth: 1)
                            .frame(width: Constants.selectIconPickerCheckmarkSize, height: Constants.selectIconPickerCheckmarkSize)
                            .foregroundStyle(Color.neutral200)
                            .overlay {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: Constants.selectIconPickerCheckmarkSize))
                                    .foregroundStyle(Color.brand500)
                                    .isHidden(iconType != presenter.iconType, remove: false)
                            }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: Constants.selectIconPickerMaxWidth)
    }
    
    @ViewBuilder
    private func showLabel() -> some View {
        Section(.customizeIconLabelHeader) {
            LabeledInput(label: String(localized: .customizeIconLabelKey), fieldWidth: $fieldWidth, minWidth: Constants.labelSettingsMinWidthLabels) {
                TextField(String(localized: .customizeIconLabelPlaceholder), text: $presenter.labelTitle)
                    .autocorrectionDisabled()
            }

            LabeledInput(label: String(localized: .customizeIconLabelColor), fieldWidth: $fieldWidth, minWidth: Constants.labelSettingsMinWidthLabels) {
                HStack {
                    Spacer()
                        .frame(maxWidth: .infinity)
                    ColorPicker("", selection: $currentColor, supportsOpacity: false)
                }
            }
            
            Button(.customizeIconLabelReset) {
                presenter.onResetColor()
            }
        }
    }
    
    @ViewBuilder
    private func showIcon() -> some View {
        Section {
            Picker(selection: $presenter.selectedDomain) {
                ForEach(presenter.uriDomains, id: \.self) { domain in
                    Text(domain)
                        .tag(domain)
                }
            } label: {}
            .pickerStyle(.inline)
        }
    }
    
    @ViewBuilder
    private func showCustom() -> some View {
        Section(.customizeIconCustomHeader) {
            TextField(String(localized: .customizeIconCustomPlaceholder), text: $presenter.urlString)
                .autocorrectionDisabled()
                .autocapitalization(.none)
                .keyboardType(.URL)
                .textContentType(.URL)
        }
    }
}

#Preview {
    let flowController = CustomizeIconFlowController(viewController: UIViewController())
    let interactor = ModuleInteractorFactory.shared.customizeIconInteractor()
    
    CustomizeIconView(presenter: CustomizeIconPresenter(
        data: CustomizeIconData(currentIconType: .domainIcon(nil), name: "", passwordName: "", uriDomains: ["example.com", "example.net"]),
        flowController: flowController,
        interactor: interactor)
    )
}
