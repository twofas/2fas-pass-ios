// SPDX-License-Identifier: BUSL-1.1
//
// Copyright © 2025 Two Factor Authentication Service, Inc.
// Licensed under the Business Source License 1.1
// See LICENSE file for full terms

import SwiftUI
import AVFoundation

struct CameraViewport: UIViewRepresentable {
    private let height = CameraViewportMetrics.cameraActiveAreaHeight
        
    var didRegisterError: (String?) -> Void
    var didFoundCode: (String) -> Void
    @Binding var cameraFreeze: Bool
    
    final class Coordinator {
        private weak var camera: CameraScanningView?
        
        private let feedbackGenerator = UINotificationFeedbackGenerator()
        private let notificationCenter = NotificationCenter.default
        
        private let parent: CameraViewport
        
        init(_ parent: CameraViewport) {
            self.parent = parent
            
            notificationCenter.addObserver(
                self,
                selector: #selector(cameraStateChanged),
                name: NSNotification.Name.AVCaptureSessionWasInterrupted,
                object: nil
            )
            notificationCenter.addObserver(
                self,
                selector: #selector(resumeCamera),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
        }
        
        func dismantle() {
            notificationCenter.removeObserver(self)
        }
        
        @objc
        private func cameraStateChanged(notification: Notification) {
            guard
                let reasonKey = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as? Int,
                let reason = AVCaptureSession.InterruptionReason(rawValue: reasonKey)
            else {
                return
            }

            let errorReason: String? = {
                switch reason {
                case .videoDeviceInUseByAnotherClient:
                    return String(localized: .cameraErrorOtherAppUsesCamera)
                case .videoDeviceNotAvailableDueToSystemPressure:
                    return String(localized: .cameraErrorSystemOverload)
                case .videoDeviceNotAvailableWithMultipleForegroundApps:
                    return String(localized: .cameraErrorSplitMode)
                case .videoDeviceNotAvailableInBackground:
                    camera?.stop()
                    return nil
                default: return String(localized: .cameraErrorGeneral)
                }
            }()
            parent.didRegisterError(errorReason)
        }
        
        @objc
        private func resumeCamera() {
            camera?.start()
        }
    }
    
    func makeUIView(context: Context) -> CameraScanningView {
        let cam = CameraScanningView()
        cam.codeFound = { didFoundCode($0) }
        return cam
    }
    
    func updateUIView(_ uiView: CameraScanningView, context: Context) {
        uiView.updateOrientation()
        
        if cameraFreeze {
            uiView.freeze()
        } else {
            uiView.unfreeze()
        }
    }
    
    func dismantleUIView(_ uiView: CameraScanningView, coordinator: Coordinator) {
        uiView.dismantle()
        coordinator.dismantle()
    }
    
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: CameraScanningView, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        return CGSize(width: width, height: height)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
}

final class CameraScanningView: UIView {
    private var camera: Camera?
    var codeFound: ((String) -> Void)?
    
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    // swiftlint:disable force_cast
    override var layer: CALayer { super.layer as! AVCaptureVideoPreviewLayer }
    // swiftlint:enable force_cast
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        
        if window == nil {
            dismantle()
        } else {
            if camera == nil {
                commonInit()
            }
        }
    }
    
    private func commonInit() {
        camera = Camera(previewView: self, scanningRegion: .init(origin: .zero, size: frame.size))
        backgroundColor = .black
        camera?.delegate = self
        camera?.startScanning()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()

        camera?.updateScanningRegion(.init(origin: .zero, size: frame.size))
        camera?.updateOrientation()
    }
    
    func stop() {
        camera?.freeze()
        camera?.stopScanning()
    }
    
    func start() {
        camera?.startScanning()
    }
    
    func dismantle() {
        camera?.stopScanning()
        camera?.delegate = nil
        camera?.clear()
        camera = nil
    }
    
    func unfreeze() {
        camera?.unfreeze()
    }
    
    func freeze() {
        camera?.freeze()
    }
    
    func updateOrientation() {
        camera?.updateOrientation()
    }
}

extension CameraScanningView: CameraDelegate {
    func didStartScanning() {}
    func didFoundCode(_ code: String) {
        codeFound?(code)
    }
}

enum CameraViewportMetrics {
    static var cameraActiveAreaHeight: CGFloat = {
        if UIDevice.isiPad {
            return 320
        }
        return 240
    }()
    static let largeSpacing: CGFloat = 15
}
