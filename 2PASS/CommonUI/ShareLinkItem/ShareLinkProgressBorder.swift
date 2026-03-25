// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import Common

/// An animated border overlay that shows a spinning progress indicator
/// while uploading, then fills to completion on success.
struct ShareLinkProgressBorder: View {

    enum Phase: Equatable {
        case idle
        case loading
        case success
    }

    private enum Constants {
        static let spinnerCycleDuration: TimeInterval = 1.3
        static let spinnerArcFraction: CGFloat = 0.1
        static let glowTrailStart: CGFloat = 0.08
        static let successGlowTrailLength: CGFloat = 0.02
        static let borderLineWidth: CGFloat = 1
        static let glowLineWidth: CGFloat = 8
        static let glowBlurRadius: CGFloat = 4
        static let glowOpacity: CGFloat = 0.5
        static let idleBorderOpacity: CGFloat = 0.2
        static let fillAnimationDuration: TimeInterval = 0.35
    }

    let cornerRadius: CGFloat
    let phase: Phase

    @State private var successStartFraction: CGFloat = 0
    @State private var borderProgress: CGFloat = 0
    @State private var spinnerStartDate: Date?
    @State private var showGlow: Bool = false

    private static let accentViolet = Color(UIColor(
        light: UIColor(hexString: "#8800FF")!.withAlphaComponent(0.5),
        dark: UIColor(hexString: "#8800FF")!.withAlphaComponent(0.8))
    )
    private static let glowViolet = Color(UIColor(hexString: "BB77FF")!)

    var body: some View {
        borderFrame
            .onChange(of: phase) { _, phase in
                switch phase {
                case .idle:
                    spinnerStartDate = nil
                    successStartFraction = 0
                    borderProgress = 0
                case .loading:
                    spinnerStartDate = Date()
                case .success:
                    if let start = spinnerStartDate {
                        let elapsed = Date().timeIntervalSince(start)
                        successStartFraction = CGFloat(
                            (elapsed / Constants.spinnerCycleDuration).truncatingRemainder(dividingBy: 1)
                        )
                    }
                    spinnerStartDate = nil
                    showGlow = true
                    borderProgress = Constants.spinnerArcFraction
                    let spinnerSpeed = 1.0 / Constants.spinnerCycleDuration
                    withAnimation(.interpolatingSpring(
                        duration: Constants.fillAnimationDuration,
                        bounce: 0,
                        initialVelocity: spinnerSpeed
                    )) {
                        borderProgress = 1
                    }
                    withAnimation(.easeOut(duration: Constants.fillAnimationDuration)) {
                        showGlow = false
                    }
                }
            }
    }

    private var borderFrame: some View {
        let borderColor = Self.accentViolet
        let glowOpacity: CGFloat = showGlow ? Constants.glowOpacity : 0
        let shape = OffsetRoundedRect(cornerRadius: cornerRadius, startFraction: successStartFraction)

        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Self.accentViolet, lineWidth: Constants.borderLineWidth)
                .opacity(Constants.idleBorderOpacity)

            if let spinnerStartDate {
                TimelineView(.animation) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(spinnerStartDate)
                    let spinnerShape = OffsetRoundedRect(
                        cornerRadius: cornerRadius,
                        startFraction: CGFloat(
                            (elapsed / Constants.spinnerCycleDuration).truncatingRemainder(dividingBy: 1)
                        )
                    )

                    spinnerShape
                        .trim(from: 0, to: Constants.spinnerArcFraction)
                        .stroke(borderColor, style: StrokeStyle(lineWidth: Constants.borderLineWidth, lineCap: .round))

                    spinnerShape
                        .trim(from: Constants.glowTrailStart, to: Constants.spinnerArcFraction)
                        .stroke(Self.glowViolet, style: StrokeStyle(lineWidth: Constants.glowLineWidth, lineCap: .round))
                        .blur(radius: Constants.glowBlurRadius)
                        .opacity(Constants.glowOpacity)
                }
            }

            shape
                .trim(from: 0, to: borderProgress)
                .stroke(borderColor, style: StrokeStyle(lineWidth: Constants.borderLineWidth, lineCap: .round))

            shape
                .trim(from: max(borderProgress - Constants.successGlowTrailLength, 0), to: borderProgress)
                .stroke(Self.glowViolet, style: StrokeStyle(lineWidth: Constants.glowLineWidth, lineCap: .round))
                .blur(radius: Constants.glowBlurRadius)
                .opacity(glowOpacity)
        }
    }
}

/// A rounded rectangle path that starts at an arbitrary position along the perimeter.
/// This allows `trim(from:to:)` to work correctly without wrapping issues.
private struct OffsetRoundedRect: Shape {
    let cornerRadius: CGFloat
    var startFraction: CGFloat

    var animatableData: CGFloat {
        get { startFraction }
        set { startFraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, min(rect.width, rect.height) / 2)
        let hEdge = rect.width - 2 * r
        let vEdge = rect.height - 2 * r
        let arcLen = CGFloat.pi / 2 * r
        let total = 2 * hEdge + 2 * vEdge + 4 * arcLen
        let target = startFraction * total

        let segLens = (hEdge, arcLen, vEdge, arcLen, hEdge, arcLen, vEdge, arcLen)
        var acc: CGFloat = 0
        var si = 0
        var sf: CGFloat = 0
        for i in 0..<8 {
            let len = segLen(segLens, at: i)
            if acc + len > target {
                si = i
                sf = len > 0 ? (target - acc) / len : 0
                break
            }
            acc += len
        }

        let arcs: [(c: CGPoint, s: CGFloat, e: CGFloat)] = [
            (CGPoint(x: rect.maxX - r, y: rect.minY + r), -.pi / 2, 0),
            (CGPoint(x: rect.maxX - r, y: rect.maxY - r), 0, .pi / 2),
            (CGPoint(x: rect.minX + r, y: rect.maxY - r), .pi / 2, .pi),
            (CGPoint(x: rect.minX + r, y: rect.minY + r), .pi, 3 * .pi / 2),
        ]

        var path = Path()
        path.move(to: pointOn(seg: si, frac: sf, rect: rect, r: r, hEdge: hEdge, vEdge: vEdge))

        for i in 0...8 {
            let idx = (si + i) % 8
            let from: CGFloat = (i == 0) ? sf : 0
            let to: CGFloat = (i == 8) ? sf : 1
            guard from < to else { continue }

            switch idx {
            case 0, 2, 4, 6:
                path.addLine(to: pointOn(seg: idx, frac: to, rect: rect, r: r, hEdge: hEdge, vEdge: vEdge))
            case 1, 3, 5, 7:
                let arc = arcs[idx / 2]
                let a0 = arc.s + from * (arc.e - arc.s)
                let a1 = arc.s + to * (arc.e - arc.s)
                path.addArc(center: arc.c, radius: r, startAngle: .radians(a0), endAngle: .radians(a1), clockwise: false)
            default:
                break
            }
        }

        return path
    }

    private func segLen(
        _ segs: (CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat, CGFloat),
        at index: Int
    ) -> CGFloat {
        switch index {
        case 0: segs.0
        case 1: segs.1
        case 2: segs.2
        case 3: segs.3
        case 4: segs.4
        case 5: segs.5
        case 6: segs.6
        case 7: segs.7
        default: 0
        }
    }

    private func pointOn(seg: Int, frac: CGFloat, rect: CGRect, r: CGFloat, hEdge: CGFloat, vEdge: CGFloat) -> CGPoint {
        switch seg % 8 {
        case 0: return CGPoint(x: rect.minX + r + frac * hEdge, y: rect.minY)
        case 1:
            let a = -CGFloat.pi / 2 + frac * CGFloat.pi / 2
            return CGPoint(x: rect.maxX - r + r * cos(a), y: rect.minY + r + r * sin(a))
        case 2: return CGPoint(x: rect.maxX, y: rect.minY + r + frac * vEdge)
        case 3:
            let a = frac * CGFloat.pi / 2
            return CGPoint(x: rect.maxX - r + r * cos(a), y: rect.maxY - r + r * sin(a))
        case 4: return CGPoint(x: rect.maxX - r - frac * hEdge, y: rect.maxY)
        case 5:
            let a = CGFloat.pi / 2 + frac * CGFloat.pi / 2
            return CGPoint(x: rect.minX + r + r * cos(a), y: rect.maxY - r + r * sin(a))
        case 6: return CGPoint(x: rect.minX, y: rect.maxY - r - frac * vEdge)
        case 7:
            let a = CGFloat.pi + frac * CGFloat.pi / 2
            return CGPoint(x: rect.minX + r + r * cos(a), y: rect.minY + r + r * sin(a))
        default: return .zero
        }
    }
}
