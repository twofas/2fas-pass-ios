// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI

struct OverlayButtonView: View {
    @State private var counter: Int = 0
    @State private var origin: CGPoint = .init(x: 15, y: 15)
    
    var action: () -> Void
    
    var body: some View {
        Button {
            let feedback = UIImpactFeedbackGenerator()
            feedback.impactOccurred(intensity: 0.5)
            
            action()
        } label: {
            Text(verbatim: "🐞")
                .font(.system(size: 30))
        }
        .frame(width: 30, height: 30)
        .modifier(RippleEffect(at: origin, trigger: counter))
        
        .edgesIgnoringSafeArea(.all)
        .background(.clear)
        .ignoresSafeArea(.all)
        .padding(0)
        .onAppear {
            counter += 1
        }
    }
}

final class HostingController: UIHostingController<OverlayButtonView> {
    private var isSet = false
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard !isSet else { return }
        isSet = true
        let safe = view.safeAreaInsets
        additionalSafeAreaInsets = .init(top: -safe.top, left: 0, bottom: 0, right: 0)
    }
}
