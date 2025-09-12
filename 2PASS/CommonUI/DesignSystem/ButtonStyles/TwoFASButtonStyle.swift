// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

public extension ButtonStyle where Self == TwoFASButtonStyle {
    
    static var filled: TwoFASButtonStyle {
        TwoFASButtonStyle(colorStyle: .filled, fillSpace: true)
    }
    
    static var filledCircle: TwoFASButtonStyle {
        TwoFASButtonStyle(colorStyle: .filled, layout: .circle, fillSpace: false)
    }
    
    static func filled(fillSpace: Bool) -> TwoFASButtonStyle {
        TwoFASButtonStyle(colorStyle: .filled, fillSpace: fillSpace)
    }
}

public extension ButtonStyle where Self == TwoFASButtonStyle {
    
    static var bezeled: TwoFASButtonStyle {
        TwoFASButtonStyle(colorStyle: .bezeled, fillSpace: true)
    }
    
    static var bezeledCircle: TwoFASButtonStyle {
        TwoFASButtonStyle(colorStyle: .bezeled, layout: .circle)
    }
    
    static func bezeled(fillSpace: Bool) -> TwoFASButtonStyle {
        TwoFASButtonStyle(colorStyle: .bezeled, fillSpace: fillSpace)
    }
}

public extension ButtonStyle where Self == TwoFASButtonStyle {
    
    static var bezeledGray: TwoFASButtonStyle {
        TwoFASButtonStyle(colorStyle: .bezeledGray, fillSpace: true)
    }
    
    static var bezeledGrayCircle: TwoFASButtonStyle {
        TwoFASButtonStyle(colorStyle: .bezeledGray, layout: .circle)
    }
    
    static func bezeledGray(fillSpace: Bool) -> TwoFASButtonStyle {
        TwoFASButtonStyle(colorStyle: .bezeledGray, fillSpace: fillSpace)
    }
}

public extension ButtonStyle where Self == TwoFASButtonStyle {
    
    static var twofasBorderless: TwoFASButtonStyle {
        TwoFASButtonStyle(colorStyle: .borderless, fillSpace: true)
    }
    
    static var twofasBorderlessCircle: TwoFASButtonStyle {
        TwoFASButtonStyle(colorStyle: .borderless, layout: .circle)
    }
    
    static func twofasBorderless(fillSpace: Bool) -> TwoFASButtonStyle {
        TwoFASButtonStyle(colorStyle: .borderless, fillSpace: fillSpace)
    }
}

private struct Constants {
    static let tapWhiteOpacity = 0.12
}

public struct TwoFASButtonStyle: ButtonStyle {
    
    enum ColorStyle {
        case filled
        case bezeled
        case bezeledGray
        case borderless
    }
    
    private let colorStyle: ColorStyle
    private let layout: ButtonLayoutType
    private let fillSpace: Bool
    
    init(colorStyle: ColorStyle, layout: ButtonLayoutType = .rectangle, fillSpace: Bool = false) {
        self.layout = layout
        self.fillSpace = fillSpace
        self.colorStyle = colorStyle
    }
    
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize
    
    @ViewBuilder
    public func makeBody(configuration: Configuration) -> some View {
        switch layout {
        case .rectangle:
            base(configuration: configuration)
                .background(
                    baseBackgroundShape
                        .foregroundStyle(backgroundColor(for: configuration))
                )
                .overlay {
                    baseOverlayShape
                        .opacity(configuration.isPressed ? Constants.tapWhiteOpacity : 0)
                }
        case .circle:
            base(configuration: configuration)
                .background(
                    Circle()
                        .foregroundStyle(backgroundColor(for: configuration))
                )
                .overlay {
                    Circle()
                        .fill(Color.white)
                        .opacity(configuration.isPressed ? Constants.tapWhiteOpacity : 0)
                }
        }
    }
    
    @ViewBuilder
    private var baseBackgroundShape: some View {
        if #available(iOS 26, *) {
            Capsule()
        } else {
            RoundedRectangle(cornerRadius: ButtonMetrics(controlSize: controlSize).cornerRadius)
        }
    }
    
    @ViewBuilder
    private var baseOverlayShape: some View {
        if #available(iOS 26, *) {
            Capsule()
        } else {
            RoundedRectangle(cornerRadius: ButtonMetrics(controlSize: controlSize).cornerRadius)
                .fill(Color.white)
        }
    }
    
    public func base(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(ButtonLabelStyle())
            .font(ButtonMetrics(controlSize: controlSize).font)
            .frame(width: layout == .circle ? ButtonMetrics(controlSize: controlSize).height : nil)
            .frame(maxWidth: fillSpace ? .infinity : nil)
            .padding(.horizontal, layout != .circle ? ButtonMetrics(controlSize: controlSize).horizontalPadding : 0)
            .frame(height: ButtonMetrics(controlSize: controlSize).height)
            .foregroundStyle(foregroundColor)
    }
    
    private var foregroundColor: Color {
        switch colorStyle {
        case .filled:
            isEnabled ? Color.baseStatic0 : Color.neutral300
        case .bezeled, .bezeledGray:
            isEnabled ? Color.brand500 : Color.neutral300
        case .borderless:
            isEnabled ? Color.brand500 : Color.neutral300
        }
    }
    
    private func backgroundColor(for configuration: Configuration) -> Color {
        switch colorStyle {
        case .filled:
            if configuration.role == .destructive {
                return isEnabled ? Color.danger500 : Color.neutral100
            } else {
                return isEnabled ? Color.brand500 : Color.neutral100
            }
        case .bezeled:
            return isEnabled ? Color.brand100 : Color.neutral100
        case .bezeledGray:
            return isEnabled ? Color.neutral50 : Color.neutral50
        case .borderless:
            return .clear
        }
    }
}

#Preview {
    @Previewable @State var isEnabled = true
    @Previewable @State var colorStyle: TwoFASButtonStyle.ColorStyle = .filled
    
    VStack {
        Picker("", selection: $colorStyle) {
            Text("Filled").tag(TwoFASButtonStyle.ColorStyle.filled)
            Text("Bezeled").tag(TwoFASButtonStyle.ColorStyle.bezeled)
            Text("Bezeled Gray").tag(TwoFASButtonStyle.ColorStyle.bezeledGray)
            Text("Borderless").tag(TwoFASButtonStyle.ColorStyle.borderless)
        }
        .pickerStyle(.segmented)
        
        Toggle("isEnabled", isOn: $isEnabled)
            .padding(.horizontal, 12)
    
        ScrollView {
            VStack(spacing: 24) {
                ButtonsPreviewView()
                    .buttonStyle(
                        TwoFASButtonStyle(colorStyle: colorStyle, layout: .rectangle, fillSpace: true)
                    )
                
                ButtonsPreviewView()
                    .buttonStyle(
                        TwoFASButtonStyle(colorStyle: colorStyle, layout: .rectangle, fillSpace: false)
                    )
                
                ButtonsPreviewView(layout: .circle)
                    .buttonStyle(
                        TwoFASButtonStyle(colorStyle: colorStyle, layout: .circle)
                    )
            }
            .disabled(isEnabled == false)
        }
    }
}
