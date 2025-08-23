//
//  CameraPreview.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 8/20/25.
//

import SwiftUI
import AVFoundation
import UIKit

// MARK: - Camera Preview

struct CoffeeGrindCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let onTap: ((CGPoint) -> Void)?
    
    init(session: AVCaptureSession, onTap: ((CGPoint) -> Void)? = nil) {
        self.session = session
        self.onTap = onTap
    }
    
    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        view.session = session
        view.onTap = onTap
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewView, context: Context) {
        uiView.session = session
        uiView.onTap = onTap
    }
}

// MARK: - Camera Preview View

class CameraPreviewView: UIView {
    var session: AVCaptureSession? {
        didSet {
            guard let session = session else { return }
            videoPreviewLayer.session = session
        }
    }
    
    var onTap: ((CGPoint) -> Void)?
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        videoPreviewLayer.videoGravity = .resizeAspectFill
        
        // Add tap gesture for focus
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        addGestureRecognizer(tapGesture)
    }
    
    @objc private func handleTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: self)
        let devicePoint = videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: location)
        onTap?(devicePoint)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        DispatchQueue.main.async {
            self.videoPreviewLayer.frame = self.bounds
        }
    }
}

// MARK: - Grid Overlay

/// A grid overlay to be placed on top of the camera preview.
/// 
/// Usage should include the same `.aspectRatio` and `.frame` modifiers as the camera preview for perfect alignment.
/// 
/// Example:
/// ```swift
/// GridOverlay(isVisible: ...)
///     .aspectRatio(3/4, contentMode: .fill)
///     .frame(maxWidth: .infinity, maxHeight: 400)
/// ```
///
/// This view does not apply any internal `.frame` or `.aspectRatio` modifiers itself.
/// Instead, layout must be managed by the parent to exactly match the camera preview's size and aspect ratio.
struct GridOverlay: View {
    let isVisible: Bool
    
    var body: some View {
        if isVisible {
            VStack(spacing: 0) {
                Spacer()
                gridLine
                Spacer()
                gridLine
                Spacer()
            }
            .overlay(
                HStack(spacing: 0) {
                    Spacer()
                    verticalGridLine
                    Spacer()
                    verticalGridLine
                    Spacer()
                }
            )
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.3), value: isVisible)
        }
    }
    
    private var gridLine: some View {
        Rectangle()
            .fill(Color.white.opacity(0.4))
            .frame(height: 1)
    }
    
    private var verticalGridLine: some View {
        Rectangle()
            .fill(Color.white.opacity(0.4))
            .frame(width: 1)
    }
}

// MARK: - Focus Indicator

struct FocusIndicator: View {
    let position: CGPoint
    let isVisible: Bool
    
    var body: some View {
        if isVisible {
            ZStack {
                SwiftUI.Circle()
                    .stroke(Color.yellow, lineWidth: 2)
                    .frame(width: 80, height: 80)
                
                SwiftUI.Circle()
                    .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                    .frame(width: 120, height: 120)
            }
            .position(position)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 1.2)
            .animation(.easeOut(duration: 0.6), value: isVisible)
        }
    }
}

// MARK: - Camera Permission View

struct CameraPermissionView: View {
    let onRequestPermission: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("Camera Access Required")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("This app needs camera access to analyze your coffee grind. Please grant permission in Settings.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            Button("Open Settings") {
                if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsUrl)
                }
            }
            .buttonStyle(.borderedProminent)
            
            Button("Try Again") {
                onRequestPermission()
            }
            .buttonStyle(.bordered)
        }
        .padding(40)
        .background(Color(.systemBackground))
    }
}

// MARK: - Camera Controls

struct CameraControls: View {
    @ObservedObject var camera: CoffeeCamera
    let onCapture: () -> Void
    let onGallery: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Top row controls
            HStack {
                Spacer()
                
                if camera.hasFlash() {
                    controlButton(
                        icon: camera.isFlashOn ? "bolt.fill" : "bolt.slash.fill",
                        label: "Flash",
                        isActive: camera.isFlashOn,
                        action: { camera.toggleFlash() }
                    )
                    
                    Spacer()
                }
                
                controlButton(
                    icon: "grid",
                    label: "Grid",
                    isActive: camera.showGrid,
                    action: { camera.toggleGrid() }
                )
                
                Spacer()
                
                controlButton(
                    icon: "photo.stack",
                    label: "Gallery",
                    isActive: false,
                    action: onGallery
                )
                
                if camera.canToggleCamera() {
                    Spacer()
                    
                    controlButton(
                        icon: "camera.rotate",
                        label: "Switch",
                        isActive: false,
                        action: { camera.switchCamera() }
                    )
                }
                
                Spacer()
            }
            
            // Centered capture button
            HStack {
                Spacer()
                
                CaptureButton(
                    isCapturing: camera.isCapturing,
                    isEnabled: camera.isSessionRunning && !camera.isCapturing,
                    onCapture: onCapture
                )
                
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
    }
    
    private func controlButton(
        icon: String,
        label: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isActive ? .yellow : .white)
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(isActive ? .yellow : .white)
            }
        }
        .disabled(!camera.isSessionRunning)
    }
}

// MARK: - Capture Button

struct CaptureButton: View {
    let isCapturing: Bool
    let isEnabled: Bool
    let onCapture: () -> Void
    
    var body: some View {
        Button(action: onCapture) {
            ZStack {
                Circle()
                    .stroke(Color.white, lineWidth: 4)
                    .frame(width: 70, height: 70)
                
                Circle()
                    .fill(isEnabled ? Color.white : Color.gray)
                    .frame(width: 60, height: 60)
                    .scaleEffect(isCapturing ? 0.8 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isCapturing)
                
                if isCapturing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                }
            }
        }
        .disabled(!isEnabled)
    }
}

