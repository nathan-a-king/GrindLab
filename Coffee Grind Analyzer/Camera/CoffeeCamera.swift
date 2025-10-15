//
//  CoffeeCamera.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 8/20/25.
//

import SwiftUI
import AVFoundation
import UIKit
import Combine

// MARK: - Camera Manager

class CoffeeCamera: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    @Published var isFlashOn = false
    @Published var showGrid = false
    @Published var isCapturing = false
    @Published var showFocusIndicator = false
    @Published var focusPoint = CGPoint(x: 100, y: 100)
    @Published var isSessionRunning = false
    @Published var authorizationStatus: AVAuthorizationStatus = .notDetermined
    
    private var photoOutput = AVCapturePhotoOutput()
    private var captureDevice: AVCaptureDevice?
    private var captureCompletion: ((Result<UIImage, CoffeeAnalysisError>) -> Void)?
    private var cancellables = Set<AnyCancellable>()
    
    override init() {
        super.init()
        updateAuthorizationStatus()
    }
    
    deinit {
        stopSession()
    }
    
    // MARK: - Session Management
    
    func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            DispatchQueue.main.async {
                self.authorizationStatus = .authorized
            }
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.authorizationStatus = granted ? .authorized : .denied
                    if granted {
                        self?.setupCamera()
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
            }
        @unknown default:
            break
        }
    }
    
    private func updateAuthorizationStatus() {
        DispatchQueue.main.async {
            self.authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        }
    }
    
    private func setupCamera() {
        guard authorizationStatus == .authorized else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.configureCaptureSession()
        }
    }
    
    private func configureCaptureSession() {
        print("🔧 Starting camera configuration...")
        
        session.beginConfiguration()
        
        // Remove existing inputs and outputs
        for input in session.inputs {
            session.removeInput(input)
            print("Removed input: \(input)")
        }
        for output in session.outputs {
            session.removeOutput(output)
            print("Removed output: \(output)")
        }
        
        // Configure camera device - Try to get the best camera for macro photography
        var device: AVCaptureDevice?
        
        // For iPhone 13 Pro and later, use ultra-wide with macro capability
        if #available(iOS 15.0, *) {
            // Try to get the ultra-wide camera which supports macro on newer devices
            device = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back)
            
            // Check if this device supports macro (minimum focus distance < 5cm)
            if let ultraWide = device, ultraWide.minimumFocusDistance < 50 {
                print("✅ Using ultra-wide camera with macro capability")
            } else {
                // Fall back to wide angle camera if ultra-wide doesn't support macro
                device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                print("ℹ️ Using standard wide angle camera")
            }
        } else {
            // For older devices, use the standard wide angle camera
            device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        }
        
        guard let cameraDevice = device else {
            print("❌ Failed to get camera device")
            session.commitConfiguration()
            return
        }
        
        print("✅ Got camera device: \(cameraDevice.localizedName)")
        print("📏 Minimum focus distance: \(cameraDevice.minimumFocusDistance)mm")
        captureDevice = cameraDevice
        
        do {
            // Create and add input
            let input = try AVCaptureDeviceInput(device: cameraDevice)
            
            guard session.canAddInput(input) else {
                print("❌ Cannot add camera input")
                session.commitConfiguration()
                return
            }
            
            session.addInput(input)
            print("✅ Camera input added successfully")
            
            // Create and add photo output
            photoOutput = AVCapturePhotoOutput()
            
            guard session.canAddOutput(photoOutput) else {
                print("❌ Cannot add photo output")
                session.commitConfiguration()
                return
            }
            
            session.addOutput(photoOutput)
            print("✅ Photo output added successfully")
            
            // Set session preset
            if session.canSetSessionPreset(.photo) {
                session.sessionPreset = .photo
                print("✅ Session preset set to photo")
            } else {
                print("⚠️ Cannot set photo preset")
            }
            
            // Configure device settings while still in configuration
            try cameraDevice.lockForConfiguration()
            
            // Optimize for macro/close-up photography
            if cameraDevice.isFocusModeSupported(.continuousAutoFocus) {
                cameraDevice.focusMode = .continuousAutoFocus
                print("✅ Continuous autofocus enabled")
            }
            
            // Set focus range restriction for close-up shots if available (iOS 15+)
            if #available(iOS 15.0, *) {
                if cameraDevice.isAutoFocusRangeRestrictionSupported {
                    // Restrict focus to near range for better macro performance
                    cameraDevice.autoFocusRangeRestriction = .near
                    print("✅ Focus range restricted to near (macro mode)")
                }
            }
            
            // Set the lens position for close focus if manual control is available
            if cameraDevice.isFocusModeSupported(.locked) && cameraDevice.isLockingFocusWithCustomLensPositionSupported {
                // Set a close focus position (0.0 = infinity, 1.0 = closest)
                // We'll use auto-focus but this helps bias it toward close objects
                let closeFocusPosition: Float = 0.8
                cameraDevice.setFocusModeLocked(lensPosition: closeFocusPosition, completionHandler: nil)
                print("✅ Initial focus position set for close-up: \(closeFocusPosition)")
                
                // Then switch back to auto for continuous adjustment
                if cameraDevice.isFocusModeSupported(.continuousAutoFocus) {
                    cameraDevice.focusMode = .continuousAutoFocus
                }
            }
            
            if cameraDevice.isExposureModeSupported(.continuousAutoExposure) {
                cameraDevice.exposureMode = .continuousAutoExposure
            }
            
            if cameraDevice.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance) {
                cameraDevice.whiteBalanceMode = .continuousAutoWhiteBalance
            }
            
            // Enable high-quality capture for better detail
            if cameraDevice.activeFormat.isHighPhotoQualitySupported {
                cameraDevice.automaticallyAdjustsVideoHDREnabled = false
                print("✅ High photo quality supported")
            }
            
            cameraDevice.unlockForConfiguration()
            print("✅ Device settings configured")
            
            // Commit all changes at once
            session.commitConfiguration()
            print("✅ Session configuration committed")
            
            // Verify configuration
            print("📊 Final verification:")
            print("   Inputs: \(session.inputs.count)")
            print("   Outputs: \(session.outputs.count)")
            
            for input in session.inputs {
                if let deviceInput = input as? AVCaptureDeviceInput {
                    print("   Input device: \(deviceInput.device.localizedName)")
                }
            }
            
            // Start session
            startSession()
            
        } catch {
            print("❌ Camera configuration error: \(error)")
            session.commitConfiguration()
        }
    }
    
    func startSession() {
        guard !session.isRunning else {
            print("Session already running")
            return
        }
        
        // Double-check our configuration before starting
        print("📊 Pre-start verification:")
        print("   Inputs: \(session.inputs.count)")
        print("   Outputs: \(session.outputs.count)")
        
        if session.inputs.isEmpty || session.outputs.isEmpty {
            print("❌ Session has no inputs or outputs - reconfiguring...")
            configureCaptureSession()
            return
        }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            print("🚀 Starting camera session...")
            self.session.startRunning()
            
            DispatchQueue.main.async {
                self.isSessionRunning = self.session.isRunning
                print("📱 Session running: \(self.isSessionRunning)")
                
                // Wait a moment for connections to be established
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    print("🔍 Checking connections after start...")
                    print("   Total connections: \(self.photoOutput.connections.count)")
                    print("   Session inputs: \(self.session.inputs.count)")
                    print("   Session outputs: \(self.session.outputs.count)")
                    
                    for (index, connection) in self.photoOutput.connections.enumerated() {
                        let mediaTypes = connection.inputPorts.map { $0.mediaType.rawValue }
                        print("   Connection \(index): media types \(mediaTypes), active: \(connection.isActive)")
                    }
                    
                    if let connection = self.photoOutput.connection(with: .video) {
                        print("✅ Video connection found and active: \(connection.isActive)")

                        // Configure connection
                        if #available(iOS 17.0, *) {
                            // Use rotation angle API on iOS 17+
                            if connection.isVideoRotationAngleSupported(90) {
                                connection.videoRotationAngle = 90
                            }
                        } else {
                            // Fallback to orientation API on earlier iOS versions
                            if connection.isVideoOrientationSupported {
                                connection.videoOrientation = .portrait
                            }
                        }

                        if connection.isVideoStabilizationSupported {
                            connection.preferredVideoStabilizationMode = .auto
                        }
                        
                    } else {
                        print("❌ Still no video connection found after session start")
                        
                        // Last resort: try to recreate the session
                        print("🔄 Attempting to recreate session...")
                        self.session.stopRunning()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.configureCaptureSession()
                        }
                    }
                }
            }
        }
    }
    
    func stopSession() {
        guard session.isRunning else { return }
        
        DispatchQueue.global(qos: .background).async { [weak self] in
            self?.session.stopRunning()
            
            DispatchQueue.main.async {
                self?.isSessionRunning = false
            }
        }
    }
    
    // MARK: - Camera Controls
    
    func toggleFlash() {
        isFlashOn.toggle()
    }
    
    func toggleGrid() {
        showGrid.toggle()
    }
    
    func focusAt(point: CGPoint) {
        guard let device = captureDevice else { return }
        
        do {
            try device.lockForConfiguration()
            
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = point
                // Use continuousAutoFocus instead of autoFocus to maintain macro capability
                if device.isFocusModeSupported(.continuousAutoFocus) {
                    device.focusMode = .continuousAutoFocus
                } else {
                    device.focusMode = .autoFocus
                }
            }
            
            // Maintain focus range restriction for macro
            if #available(iOS 15.0, *) {
                if device.isAutoFocusRangeRestrictionSupported {
                    device.autoFocusRangeRestriction = .near
                }
            }
            
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
            
            // Remove focus indicator animation that was causing layout issues
            // iOS provides its own native focus feedback
            
        } catch {
            print("Focus error: \(error)")
        }
    }
    
    // MARK: - Photo Capture
    
    func capturePhoto(completion: @escaping (Result<UIImage, CoffeeAnalysisError>) -> Void) {
        guard !isCapturing else {
            completion(.failure(.cameraError("Capture already in progress")))
            return
        }
        
        guard session.isRunning else {
            completion(.failure(.cameraError("Camera session is not running")))
            return
        }
        
        // Wait a moment for connection to be ready if needed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Check if we have an active connection
            guard let videoConnection = self.photoOutput.connection(with: .video),
                  videoConnection.isActive else {
                print("Available connections: \(self.photoOutput.connections)")
                completion(.failure(.cameraError("No active camera connection. Try waiting a moment and try again.")))
                return
            }
            
            self.captureCompletion = completion
            self.isCapturing = true
            
            var settings = AVCapturePhotoSettings()
            
            // Use basic JPEG format to avoid compatibility issues
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            
            // Flash configuration
            if self.photoOutput.supportedFlashModes.contains(.on) && self.isFlashOn {
                settings.flashMode = .on
            } else if self.photoOutput.supportedFlashModes.contains(.off) {
                settings.flashMode = .off
            }
            
            // High resolution capture using modern API
            if #available(iOS 16.0, *) {
                // Prefer the photo output's maximum supported dimensions when available
                let supportedMax = self.photoOutput.maxPhotoDimensions
                // Only assign if dimensions look valid (non-zero)
                if supportedMax.width > 0 && supportedMax.height > 0 {
                    settings.maxPhotoDimensions = supportedMax
                }
            } else {
                // Fallback for iOS < 16: keep previous behavior
                settings.isHighResolutionPhotoEnabled = self.photoOutput.isHighResolutionCaptureEnabled
            }
            
            // Auto-stabilization
            if self.photoOutput.isStillImageStabilizationSupported {
                settings.isAutoStillImageStabilizationEnabled = true
            }
            
            print("Capturing photo with settings: \(settings)")
            print("Video connection active: \(videoConnection.isActive)")
            
            self.photoOutput.capturePhoto(with: settings, delegate: self)
            
            // Reset capture state after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.isCapturing = false
            }
        }
    }
    
    // MARK: - Utility Methods
    
    func hasFlash() -> Bool {
        return captureDevice?.hasFlash ?? false
    }
    
    func canToggleCamera() -> Bool {
        return AVCaptureDevice.devices(for: .video).count > 1
    }
    
    func switchCamera() {
        guard canToggleCamera() else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.session.beginConfiguration()
            
            // Get current input
            guard let currentInput = self.session.inputs.first as? AVCaptureDeviceInput else {
                self.session.commitConfiguration()
                return
            }
            
            // Determine new position
            let newPosition: AVCaptureDevice.Position = currentInput.device.position == .back ? .front : .back
            
            // Get new device
            guard let newDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: newPosition) else {
                self.session.commitConfiguration()
                return
            }
            
            do {
                // Remove current input
                self.session.removeInput(currentInput)
                
                // Add new input
                let newInput = try AVCaptureDeviceInput(device: newDevice)
                if self.session.canAddInput(newInput) {
                    self.session.addInput(newInput)
                    self.captureDevice = newDevice
                }
                
            } catch {
                print("Camera switch error: \(error)")
                // Add back the original input if switching failed
                if self.session.canAddInput(currentInput) {
                    self.session.addInput(currentInput)
                }
            }
            
            self.session.commitConfiguration()
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CoffeeCamera: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer {
            captureCompletion = nil
        }
        
        if let error = error {
            captureCompletion?(.failure(.cameraError("Capture failed: \(error.localizedDescription)")))
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            captureCompletion?(.failure(.cameraError("Failed to get image data")))
            return
        }
        
        guard let image = UIImage(data: imageData) else {
            captureCompletion?(.failure(.cameraError("Failed to create image from data")))
            return
        }
        
        // Process and orient the image correctly
        let orientedImage = image.fixedOrientation()
        captureCompletion?(.success(orientedImage))
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        // Optional: Add capture animation or sound here
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        // Optional: Add post-capture feedback here
    }
}

// MARK: - UIImage Extensions

extension UIImage {
    func fixedOrientation() -> UIImage {
        if imageOrientation == .up {
            return self
        }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return normalizedImage ?? self
    }
}
