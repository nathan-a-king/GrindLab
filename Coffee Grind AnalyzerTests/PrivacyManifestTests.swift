//
//  PrivacyManifestTests.swift
//  Coffee Grind AnalyzerTests
//
//  Tests for privacy manifest (PrivacyInfo.xcprivacy) validation
//  Ensures App Store compliance and proper privacy declarations
//

import Testing
import Foundation
@testable import GrindLab

struct PrivacyManifestTests {

    // MARK: - Helper Methods

    /// Loads and parses the PrivacyInfo.xcprivacy file from the main bundle
    /// - Returns: Dictionary representation of the privacy manifest, or nil if file cannot be loaded
    func loadPrivacyManifest() -> [String: Any]? {
        guard let url = Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy") else {
            print("❌ PrivacyInfo.xcprivacy not found in main bundle")
            return nil
        }

        guard let data = try? Data(contentsOf: url) else {
            print("❌ Failed to load data from PrivacyInfo.xcprivacy")
            return nil
        }

        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            print("❌ Failed to parse PrivacyInfo.xcprivacy as property list")
            return nil
        }

        return plist
    }

    // MARK: - User Story 1 Tests (TDD Red Phase)

    /// T008: Verify PrivacyInfo.xcprivacy file exists and can be loaded from bundle
    @Test func testPrivacyManifestFileExists() async throws {
        let manifest = loadPrivacyManifest()
        #expect(manifest != nil, "PrivacyInfo.xcprivacy should exist in bundle and be loadable")
    }

    /// T009: Verify privacy manifest is a valid PropertyList with dictionary structure
    @Test func testPrivacyManifestIsValidPlist() async throws {
        let manifest = loadPrivacyManifest()
        #expect(manifest != nil, "Privacy manifest should parse as valid PropertyList dictionary")
    }

    /// T010: Verify NSPrivacyTracking key exists and is a boolean value
    @Test func testNSPrivacyTrackingExists() async throws {
        let manifest = loadPrivacyManifest()
        #expect(manifest != nil, "Privacy manifest should be loaded")

        let trackingValue = manifest?["NSPrivacyTracking"]
        #expect(trackingValue != nil, "NSPrivacyTracking key should exist")

        if let tracking = trackingValue as? Bool {
            #expect(tracking == false, "NSPrivacyTracking should be false (no tracking)")
        } else {
            Issue.record("NSPrivacyTracking should be a boolean value")
        }
    }

    /// T011: Verify NSPrivacyCollectedDataTypes array exists
    @Test func testNSPrivacyCollectedDataTypesExists() async throws {
        let manifest = loadPrivacyManifest()
        #expect(manifest != nil, "Privacy manifest should be loaded")

        let dataTypes = manifest?["NSPrivacyCollectedDataTypes"]
        #expect(dataTypes != nil, "NSPrivacyCollectedDataTypes key should exist")
        #expect(dataTypes is [[String: Any]], "NSPrivacyCollectedDataTypes should be an array of dictionaries")
    }

    /// T012: Verify photos/videos data collection is properly declared
    @Test func testPhotoVideoDataCollectionDeclared() async throws {
        let manifest = loadPrivacyManifest()
        #expect(manifest != nil, "Privacy manifest should be loaded")

        guard let dataTypes = manifest?["NSPrivacyCollectedDataTypes"] as? [[String: Any]] else {
            Issue.record("NSPrivacyCollectedDataTypes should be an array")
            return
        }

        // Find photos/videos declaration
        let photoVideoDeclaration = dataTypes.first { declaration in
            (declaration["NSPrivacyCollectedDataType"] as? String) == "NSPrivacyCollectedDataTypePhotosorVideos"
        }

        #expect(photoVideoDeclaration != nil, "Photos/Videos data type should be declared")

        if let declaration = photoVideoDeclaration {
            #expect(declaration["NSPrivacyCollectedDataTypeLinked"] as? Bool == true, "Photos should be linked to user")
            #expect(declaration["NSPrivacyCollectedDataTypeTracking"] as? Bool == false, "Photos should not be used for tracking")

            let purposes = declaration["NSPrivacyCollectedDataTypePurposes"] as? [String]
            #expect(purposes != nil, "Purposes array should exist")
            #expect(purposes?.contains("NSPrivacyCollectedDataTypePurposeAppFunctionality") == true, "Purpose should be AppFunctionality")
        }
    }

    /// T013: Verify NSPrivacyAccessedAPITypes array exists
    @Test func testNSPrivacyAccessedAPITypesExists() async throws {
        let manifest = loadPrivacyManifest()
        #expect(manifest != nil, "Privacy manifest should be loaded")

        let apiTypes = manifest?["NSPrivacyAccessedAPITypes"]
        #expect(apiTypes != nil, "NSPrivacyAccessedAPITypes key should exist")
        #expect(apiTypes is [[String: Any]], "NSPrivacyAccessedAPITypes should be an array of dictionaries")
    }

    /// T014: Verify UserDefaults API is declared with CA92.1 reason code
    @Test func testUserDefaultsAPIDeclared() async throws {
        let manifest = loadPrivacyManifest()
        #expect(manifest != nil, "Privacy manifest should be loaded")

        guard let apiTypes = manifest?["NSPrivacyAccessedAPITypes"] as? [[String: Any]] else {
            Issue.record("NSPrivacyAccessedAPITypes should be an array")
            return
        }

        // Find UserDefaults declaration
        let userDefaultsDeclaration = apiTypes.first { declaration in
            (declaration["NSPrivacyAccessedAPIType"] as? String) == "NSPrivacyAccessedAPICategoryUserDefaults"
        }

        #expect(userDefaultsDeclaration != nil, "UserDefaults API type should be declared")

        if let declaration = userDefaultsDeclaration {
            let reasons = declaration["NSPrivacyAccessedAPITypeReasons"] as? [String]
            #expect(reasons != nil, "Reason codes array should exist")
            #expect(reasons?.contains("CA92.1") == true, "UserDefaults should have CA92.1 reason code (app-only access)")
        }
    }

    /// T015: Verify FileTimestamp API is declared with C617.1 reason code
    @Test func testFileTimestampAPIDeclared() async throws {
        let manifest = loadPrivacyManifest()
        #expect(manifest != nil, "Privacy manifest should be loaded")

        guard let apiTypes = manifest?["NSPrivacyAccessedAPITypes"] as? [[String: Any]] else {
            Issue.record("NSPrivacyAccessedAPITypes should be an array")
            return
        }

        // Find FileTimestamp declaration
        let fileTimestampDeclaration = apiTypes.first { declaration in
            (declaration["NSPrivacyAccessedAPIType"] as? String) == "NSPrivacyAccessedAPICategoryFileTimestamp"
        }

        #expect(fileTimestampDeclaration != nil, "FileTimestamp API type should be declared")

        if let declaration = fileTimestampDeclaration {
            let reasons = declaration["NSPrivacyAccessedAPITypeReasons"] as? [String]
            #expect(reasons != nil, "Reason codes array should exist")
            #expect(reasons?.contains("C617.1") == true, "FileTimestamp should have C617.1 reason code (app container files)")
        }
    }
}
