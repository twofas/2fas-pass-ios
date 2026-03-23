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

    let cornerRadius: CGFloat
    let isUploading: Bool
    let isSuccess: Bool

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
            .onChange(of: isUploading) { _, uploading in
                if uploading {
                    spinnerStartDate = Date()
                } else {
                    spinnerStartDate = nil
                    successStartFraction = 0
                    borderProgress = 0
                }
            }
            .onChange(of: isSuccess) { _, success in
                if success {
                    if let start = spinnerStartDate {
                        let elapsed = Date().timeIntervalSince(start)
                        successStartFraction = CGFloat((elapsed / 1.3).truncatingRemainder(dividingBy: 1))
                    }
                    spinnerStartDate = nil
                    showGlow = true
                    borderProgress = 0.1
                    let spinnerSpeed = 1.0 / 1.3
                    withAnimation(.interpolatingSpring(duration: 0.35, bounce: 0, initialVelocity: spinnerSpeed)) {
                        borderProgress = 1
                    }
                    withAnimation(.easeOut(duration: 0.35)) {
                        showGlow = false
                    }
                }
            }
    }

    private var borderFrame: some View {
        let borderColor = Self.accentViolet
        let glowOpacity: CGFloat = showGlow ? 0.5 : 0
        let shape = OffsetRoundedRect(cornerRadius: cornerRadius, startFraction: successStartFraction)

        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Self.accentViolet, lineWidth: 1)
                .opacity(0.2)

            if let spinnerStartDate {
                TimelineView(.animation) { timeline in
                    let elapsed = timeline.date.timeIntervalSince(spinnerStartDate)
                    let phase = CGFloat((elapsed / 1.3).truncatingRemainder(dividingBy: 1))

                    OffsetRoundedRect(cornerRadius: cornerRadius, startFraction: phase)
                        .trim(from: 0, to: 0.1)
                        .stroke(borderColor, style: StrokeStyle(lineWidth: 1, lineCap: .round))

                    OffsetRoundedRect(cornerRadius: cornerRadius, startFraction: phase)
                        .trim(from: 0.08, to: 0.1)
                        .stroke(Self.glowViolet, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .blur(radius: 4)
                        .opacity(0.5)
                }
            }

            shape
                .trim(from: 0, to: borderProgress)
                .stroke(borderColor, style: StrokeStyle(lineWidth: 1, lineCap: .round))

            shape
                .trim(from: max(borderProgress - 0.02, 0), to: borderProgress)
                .stroke(Self.glowViolet, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .blur(radius: 4)
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

        let segLens = [hEdge, arcLen, vEdge, arcLen, hEdge, arcLen, vEdge, arcLen]
        let total = segLens.reduce(0, +)
        let target = startFraction * total

        var acc: CGFloat = 0
        var si = 0
        var sf: CGFloat = 0
        for i in 0..<8 {
            if acc + segLens[i] > target {
                si = i
                sf = segLens[i] > 0 ? (target - acc) / segLens[i] : 0
                break
            }
            acc += segLens[i]
        }

        let arcs: [(c: CGPoint, s: CGFloat, e: CGFloat)] = [
            (CGPoint(x: rect.maxX - r, y: rect.minY + r), -.pi / 2, 0),
            (CGPoint(x: rect.maxX - r, y: rect.maxY - r), 0, .pi / 2),
            (CGPoint(x: rect.minX + r, y: rect.maxY - r), .pi / 2, .pi),
            (CGPoint(x: rect.minX + r, y: rect.minY + r), .pi, 3 * .pi / 2),
        ]

        var path = Path()
        path.move(to: pointOn(seg: si, frac: sf, rect: rect, r: r))

        for i in 0...8 {
            let idx = (si + i) % 8
            let from: CGFloat = (i == 0) ? sf : 0
            let to: CGFloat = (i == 8) ? sf : 1
            guard from < to else { continue }

            switch idx {
            case 0:
                path.addLine(to: pointOn(seg: 0, frac: to, rect: rect, r: r))
            case 2:
                path.addLine(to: pointOn(seg: 2, frac: to, rect: rect, r: r))
            case 4:
                path.addLine(to: pointOn(seg: 4, frac: to, rect: rect, r: r))
            case 6:
                path.addLine(to: pointOn(seg: 6, frac: to, rect: rect, r: r))
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

    private func pointOn(seg: Int, frac: CGFloat, rect: CGRect, r: CGFloat) -> CGPoint {
        let hEdge = rect.width - 2 * r
        let vEdge = rect.height - 2 * r
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
