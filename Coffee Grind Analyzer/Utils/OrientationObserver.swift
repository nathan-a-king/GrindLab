//
//  OrientationObserver.swift
//  Coffee Grind Analyzer
//
//  Created by Claude on 10/13/25.
//

import SwiftUI
import Combine

/// Observes device orientation changes and provides reactive updates
class OrientationObserver: ObservableObject {
    @Published var orientation: UIDeviceOrientation = UIDevice.current.orientation
    @Published var isLandscape: Bool = false

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Set initial orientation
        updateOrientation()

        // Subscribe to orientation changes
        NotificationCenter.default
            .publisher(for: UIDevice.orientationDidChangeNotification)
            .sink { [weak self] _ in
                self?.updateOrientation()
            }
            .store(in: &cancellables)
    }

    private func updateOrientation() {
        let currentOrientation = UIDevice.current.orientation

        // Only update for valid orientations
        guard currentOrientation.isValidInterfaceOrientation else { return }

        orientation = currentOrientation

        // Determine if landscape
        isLandscape = currentOrientation.isLandscape
    }
}

// MARK: - Environment Key

struct OrientationKey: EnvironmentKey {
    static let defaultValue = OrientationObserver()
}

extension EnvironmentValues {
    var orientationObserver: OrientationObserver {
        get { self[OrientationKey.self] }
        set { self[OrientationKey.self] = newValue }
    }
}

// MARK: - View Extension

extension View {
    /// Provides a convenient way to detect if the device is in landscape orientation
    func onOrientationChange(_ onChange: @escaping (Bool) -> Void) -> some View {
        self.onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
            let orientation = UIDevice.current.orientation
            if orientation.isValidInterfaceOrientation {
                onChange(orientation.isLandscape)
            }
        }
    }
}

// MARK: - Size Class Helper

struct LayoutOrientation {
    let horizontal: UserInterfaceSizeClass?
    let vertical: UserInterfaceSizeClass?

    /// Returns true if the device is in landscape orientation based on size classes
    var isLandscape: Bool {
        // On iPhone, compact width + compact height = landscape
        // On iPad, regular width = landscape (among other combinations)
        if horizontal == .compact && vertical == .compact {
            return true
        }

        // Additional check using UIDevice for accuracy
        let deviceOrientation = UIDevice.current.orientation
        if deviceOrientation.isValidInterfaceOrientation {
            return deviceOrientation.isLandscape
        }

        return false
    }

    /// Returns true if device is in portrait orientation
    var isPortrait: Bool {
        !isLandscape
    }
}

extension View {
    /// Provides layout orientation based on size classes and device orientation
    func adaptiveLayout<Content: View>(
        @ViewBuilder portrait: @escaping () -> Content,
        @ViewBuilder landscape: @escaping () -> Content
    ) -> some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            Group {
                if isLandscape {
                    landscape()
                } else {
                    portrait()
                }
            }
        }
    }
}
