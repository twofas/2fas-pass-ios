// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import CommonUI

private struct Constants {
    static let overlayColor = Color.black.opacity(0.7)

    static let activeSquareSize = 244.0
    static let activeSquareCornerRadius = 24.0
    static let activeSquareCornerOffset = 105.0
}

struct ScanQRCodeCameraView: View {
    
    let title: Text
    let description: Text
    let codeFound: (String) -> Void
    
    var body: some View {
        CameraScanningView_UIKit(codeFound: codeFound)
            .ignoresSafeArea()
            .overlay {
                activeSquareView
            }
            .overlay {
                descriptionView
            }
            .onAppear {
                UIApplication.shared.isIdleTimerDisabled = true
            }
            .onDisappear {
                UIApplication.shared.isIdleTimerDisabled = false
            }
    }
    
    private var activeSquareView: some View {
        ZStack {
            Constants.overlayColor
                .ignoresSafeArea()
            
            RoundedRectangle(cornerRadius: Constants.activeSquareCornerRadius)
                .frame(width: Constants.activeSquareSize, height: Constants.activeSquareSize)
                .blendMode(.destinationOut)
        }
        .overlay {
            Image(.qrcodeCorner)
                .offset(x: -Constants.activeSquareCornerOffset, y: -Constants.activeSquareCornerOffset)
            
            Image(.qrcodeCorner)
                .rotationEffect(.degrees(90))
                .offset(x: Constants.activeSquareCornerOffset, y: -Constants.activeSquareCornerOffset)
            
            Image(.qrcodeCorner)
                .rotationEffect(.degrees(180))
                .offset(x: Constants.activeSquareCornerOffset, y: Constants.activeSquareCornerOffset)
            
            Image(.qrcodeCorner)
                .rotationEffect(.degrees(270))
                .offset(x: -Constants.activeSquareCornerOffset, y: Constants.activeSquareCornerOffset)
        }
        .ignoresSafeArea(edges: .top)
        .compositingGroup()
    }
    
    private var descriptionView: some View {
        GeometryReader { geometry in
            VStack {
                Spacer(minLength: geometry.size.height / 2 + Constants.activeSquareSize / 2 + Spacing.xll)
                
                VStack(spacing: Spacing.s) {
                    title
                        .font(.title3Emphasized)
                    
                    description
                        .font(.subheadline)
                }
                .foregroundStyle(.baseStatic0)
                .frame(width: geometry.size.width - Spacing.xxl4 * 2)
                .multilineTextAlignment(.center)
                
                Spacer()
            }
            .frame(width: geometry.size.width)
        }
        .ignoresSafeArea(edges: .top)
    }
}

private struct CameraScanningView_UIKit: UIViewRepresentable {
    
    let codeFound: (String) -> Void
    
    func makeUIView(context: Context) -> CameraScanningView {
        CameraScanningView()
    }
    
    func updateUIView(_ uiView: CameraScanningView, context: Context) {
        uiView.codeFound = codeFound
    }
}
