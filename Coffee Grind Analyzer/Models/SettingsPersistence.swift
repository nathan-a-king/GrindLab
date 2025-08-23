//
//  SettingsPersistence.swift
//  Coffee Grind Analyzer
//
//  Created by Nathan King on 8/22/25.
//

import Foundation

// MARK: - Simple Settings Extension

extension AnalysisSettings {
    private static let settingsKey = "CoffeeGrindAnalyzer_Settings"
    
    /// Save current settings to UserDefaults
    func save() {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(self) {
            UserDefaults.standard.set(encoded, forKey: Self.settingsKey)
            print("💾 Settings saved")
        }
    }
    
    /// Load settings from UserDefaults
    static func load() -> AnalysisSettings {
        guard let data = UserDefaults.standard.data(forKey: settingsKey) else {
            print("📱 No saved settings found, using defaults")
            return AnalysisSettings()
        }
        
        let decoder = JSONDecoder()
        if let settings = try? decoder.decode(AnalysisSettings.self, from: data) {
            print("📱 Settings loaded successfully")
            return settings
        } else {
            print("⚠️ Failed to decode settings, using defaults")
            return AnalysisSettings()
        }
    }
    
    /// Reset to defaults
    static func resetToDefaults() {
        UserDefaults.standard.removeObject(forKey: settingsKey)
        print("🔄 Settings reset to defaults")
    }
}

// MARK: - Make AnalysisSettings Codable

extension AnalysisSettings: Codable {
    enum CodingKeys: String, CodingKey {
        case analysisMode, contrastThreshold, minParticleSize, maxParticleSize, enableAdvancedFiltering, calibrationFactor
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let modeRawValue = try container.decode(Int.self, forKey: .analysisMode)
        self.analysisMode = AnalysisMode(rawValue: modeRawValue) ?? .standard
        
        self.contrastThreshold = try container.decode(Double.self, forKey: .contrastThreshold)
        self.minParticleSize = try container.decode(Int.self, forKey: .minParticleSize)
        self.maxParticleSize = try container.decode(Int.self, forKey: .maxParticleSize)
        self.enableAdvancedFiltering = try container.decode(Bool.self, forKey: .enableAdvancedFiltering)
        self.calibrationFactor = try container.decode(Double.self, forKey: .calibrationFactor)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(analysisMode.rawValue, forKey: .analysisMode)
        try container.encode(contrastThreshold, forKey: .contrastThreshold)
        try container.encode(minParticleSize, forKey: .minParticleSize)
        try container.encode(maxParticleSize, forKey: .maxParticleSize)
        try container.encode(enableAdvancedFiltering, forKey: .enableAdvancedFiltering)
        try container.encode(calibrationFactor, forKey: .calibrationFactor)
    }
}
