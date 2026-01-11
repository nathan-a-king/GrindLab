# Research: Apple Privacy Manifest Requirements

**Feature**: Complete Privacy Manifest with Required Declarations
**Date**: 2026-01-11
**Status**: Completed

## Executive Summary

This research clarifies Apple's PrivacyInfo.xcprivacy requirements for the Coffee Grind Analyzer app. **Critical Finding**: Camera and photo library access are **NOT** part of Apple's "required reason API" system—they continue to use traditional Info.plist permission keys. The privacy manifest is required for documenting data collection practices and declaring usage of specific "required reason APIs" like UserDefaults and file timestamp APIs.

---

## Research Findings

### 1. Privacy Manifest Schema Structure

**Decision**: Use Apple's four top-level key structure in PrivacyInfo.xcprivacy

**XML Structure**:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>
    <false/>

    <key>NSPrivacyCollectedDataTypes</key>
    <array>...</array>

    <key>NSPrivacyAccessedAPITypes</key>
    <array>...</array>
</dict>
</plist>
```

**Rationale**: This is Apple's official schema as of 2026. The four top-level keys are:
1. **NSPrivacyTracking** (Boolean) - Declares if app tracks users across apps/websites
2. **NSPrivacyTrackingDomains** (Array, optional) - Internet domains used for tracking
3. **NSPrivacyCollectedDataTypes** (Array) - Documents what data the app collects
4. **NSPrivacyAccessedAPITypes** (Array) - Declares usage of "required reason APIs"

**Alternative Considered**: Minimal manifest with only NSPrivacyAccessedAPITypes was rejected because NSPrivacyCollectedDataTypes is needed to properly document photo/video data collection for App Store privacy labels.

---

### 2. Camera Access - NOT a Required Reason API

**Decision**: Camera access uses Info.plist only, NOT the privacy manifest's NSPrivacyAccessedAPITypes

**Implementation**:
```xml
<!-- In Info.plist, NOT PrivacyInfo.xcprivacy -->
<key>NSCameraUsageDescription</key>
<string>Coffee Grind Analyzer uses the camera to capture images of your coffee grounds for consistency analysis.</string>
```

**Rationale**:
- AVFoundation camera APIs are not part of Apple's "required reason API" categories
- Camera continues to use the traditional permission model introduced in iOS 10
- NSCameraUsageDescription in Info.plist is mandatory and triggers the system permission dialog
- No NSPrivacyAccessedAPIType or NSPrivacyAccessedAPITypeReasons codes exist for camera

**Alternative Considered**: Adding camera to NSPrivacyAccessedAPITypes was rejected because:
1. Apple's official documentation confirms camera is not a required reason API
2. No valid NSPrivacyAccessedAPIType value exists for camera
3. This would cause App Store Connect validation errors

**Sources**:
- [NSCameraUsageDescription | Apple Developer Documentation](https://developer.apple.com/documentation/BundleResources/Information-Property-List/NSCameraUsageDescription)
- [Describing use of required reason API | Apple Developer Documentation](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api)

---

### 3. Photo Library Access - NOT a Required Reason API

**Decision**: Photo library uses Info.plist (NSPhotoLibraryAddUsageDescription for write-only access)

**Implementation**:
```xml
<!-- In Info.plist, NOT PrivacyInfo.xcprivacy -->
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Coffee Grind Analyzer can save your grind analysis results and images to your photo library.</string>
```

**Rationale**:
- Coffee Grind Analyzer only **saves** photos (analysis results), never reads existing photos
- NSPhotoLibraryAddUsageDescription (iOS 11+) grants write-only access, which is more privacy-preserving
- Photo library APIs are not part of the four required reason API categories
- No NSPrivacyAccessedAPIType value exists for photo library

**Alternative Considered**: Using NSPhotoLibraryUsageDescription (read/write access) was rejected because:
- The app doesn't need to read existing photos from the user's library
- Write-only access (Add) is more privacy-friendly and follows principle of least privilege
- App Store review favors minimal permission requests

**Sources**:
- [NSPhotoLibraryAddUsageDescription | Apple Developer Documentation](https://developer.apple.com/documentation/bundleresources/information-property-list/nsphotolibraryaddusagedescription)
- [NSPhotoLibraryUsageDescription | Apple Developer Documentation](https://developer.apple.com/documentation/BundleResources/Information-Property-List/NSPhotoLibraryUsageDescription)

---

### 4. Data Collection Declaration for Photos/Videos

**Decision**: Declare photo/video data collection in NSPrivacyCollectedDataTypes

**Implementation**:
```xml
<key>NSPrivacyCollectedDataTypes</key>
<array>
    <dict>
        <key>NSPrivacyCollectedDataType</key>
        <string>NSPrivacyCollectedDataTypePhotosorVideos</string>
        <key>NSPrivacyCollectedDataTypeLinked</key>
        <true/>
        <key>NSPrivacyCollectedDataTypeTracking</key>
        <false/>
        <key>NSPrivacyCollectedDataTypePurposes</key>
        <array>
            <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
        </array>
    </dict>
</array>
```

**Rationale**:
- **NSPrivacyCollectedDataTypePhotosorVideos**: Correct type for images captured/stored by the app
- **Linked = true**: Photos are linked to the user (saved to their personal library)
- **Tracking = false**: Images are not used for cross-app/site tracking
- **Purpose = AppFunctionality**: Grind analysis is core app functionality, not analytics/advertising

**Alternative Considered**: Omitting data collection declaration was rejected because:
- App Store privacy labels require accurate data collection documentation
- Transparency builds user trust and reduces rejection risk
- Complete declaration prevents future App Store review issues

**Sources**:
- [NSPrivacyCollectedDataType | Apple Developer Documentation](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacycollecteddatatypes/nsprivacycollecteddatatype)
- [Describing data use in privacy manifests | Apple Developer Documentation](https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests)

---

### 5. Required Reason APIs Used by Coffee Grind Analyzer

**Decision**: Declare UserDefaults and File Timestamp API usage with appropriate reason codes

**Implementation**:
```xml
<key>NSPrivacyAccessedAPITypes</key>
<array>
    <!-- UserDefaults for app settings -->
    <dict>
        <key>NSPrivacyAccessedAPIType</key>
        <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
        <key>NSPrivacyAccessedAPITypeReasons</key>
        <array>
            <string>CA92.1</string>
        </array>
    </dict>

    <!-- File timestamps for analysis history -->
    <dict>
        <key>NSPrivacyAccessedAPIType</key>
        <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
        <key>NSPrivacyAccessedAPITypeReasons</key>
        <array>
            <string>C617.1</string>
        </array>
    </dict>
</array>
```

**Rationale**:

**UserDefaults (CA92.1 reason code)**:
- Coffee Grind Analyzer uses UserDefaults for settings persistence (SettingsPersistence.swift)
- **CA92.1**: "Access UserDefaults to read/write information only accessible to the app itself"
- This code is correct because settings are not shared with app extensions or app groups
- App uses standard app-only storage pattern

**File Timestamps (C617.1 reason code)**:
- CoffeeAnalysisHistoryManager.swift manages saved analysis history using file operations
- **C617.1**: "Access timestamps/metadata of files inside app container, app group container, or CloudKit container"
- This code is correct because the app reads file modification dates for sorting analysis history
- Files are within the app's Documents directory (app container)

**Four Required Reason API Categories**:
1. **NSPrivacyAccessedAPICategoryFileTimestamp** - File timestamp/metadata APIs ✅ Used
2. **NSPrivacyAccessedAPICategorySystemBootTime** - System uptime calculation ❌ Not used
3. **NSPrivacyAccessedAPICategoryDiskSpace** - Disk space query APIs ❌ Not used
4. **NSPrivacyAccessedAPICategoryUserDefaults** - UserDefaults APIs ✅ Used

**Alternatives Considered**:
- **1C8F.1 for UserDefaults**: Rejected because app doesn't use App Groups or share data with extensions
- **DDA9.1 for FileTimestamp**: Rejected because app doesn't display timestamps to users, only uses them internally for sorting
- Omitting declarations: Rejected because App Store Connect validation (enforced since May 1, 2024) rejects apps using required reason APIs without declarations

**Sources**:
- [TN3183: Adding Required Reason API Entries](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest)
- [NSPrivacyAccessedAPIType | Apple Developer Documentation](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)

---

### 6. Tracking Declaration

**Decision**: Set NSPrivacyTracking to false (no tracking)

**Implementation**:
```xml
<key>NSPrivacyTracking</key>
<false/>
```

**Rationale**:
- Coffee Grind Analyzer performs no cross-app or cross-site tracking
- No third-party analytics SDKs (no Firebase, Mixpanel, etc.)
- No advertising SDKs
- All data processing is local (UserDefaults + file system)
- No network calls (per constitution: fully offline-capable)

**Alternative Considered**: Omitting NSPrivacyTracking key was rejected because:
- Explicitly declaring `false` improves clarity and App Store review experience
- Shows intentional privacy design rather than accidental omission

**Sources**:
- [Privacy manifest files | Apple Developer Documentation](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)

---

### 7. Validation Strategy

**Decision**: Three-tier validation approach (local → Xcode → App Store Connect)

**Tier 1: Local Syntax Validation**
```bash
plutil -lint Coffee\ Grind\ Analyzer/PrivacyInfo.xcprivacy
```
- Validates XML/plist syntax
- Catches malformed structure
- Fast feedback during development
- **Limitation**: Cannot validate semantic correctness of keys/values

**Tier 2: Xcode Privacy Report**
1. Product → Archive
2. Right-click archive → "Generate Privacy Report"
3. Review consolidated report from app + dependencies

**What it validates**:
- Combines all privacy manifests from app and third-party SDKs
- Checks that data types and reason codes are from Apple's approved lists
- Generates preview of App Store privacy nutrition label
- **Limitation**: Doesn't catch missing required reason API declarations (only validates present ones)

**Tier 3: App Store Connect Upload**
- Upload archive to App Store Connect (TestFlight or submission)
- Apple's server-side validation runs automatically
- Returns ITMS error codes if validation fails

**Common Error Codes**:
- **ITMS-91053**: Missing API declaration for required reason APIs
- **ITMS-90683**: Missing purpose string in Info.plist
- **ITMS-91056**: Invalid privacy manifest

**Rationale**:
- Multi-tier approach catches different types of errors at different stages
- Syntax errors caught early (local) save time vs waiting for App Store validation
- Xcode Privacy Report validates semantic correctness
- App Store Connect is the ultimate authority but slowest to get feedback

**Alternative Considered**: Manual review only was rejected because:
- Human error likely with complex XML structures
- Automated validation catches typos and invalid values
- App Store rejection is expensive (delays release timeline)

**Sources**:
- [TN3181: Debugging an Invalid Privacy Manifest](https://developer.apple.com/documentation/technotes/tn3181-debugging-invalid-privacy-manifest)
- [plutil man page](https://keith.github.io/xcode-man-pages/plutil.1.html)

---

## Complete Implementation Example

### PrivacyInfo.xcprivacy (Final)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- No tracking -->
    <key>NSPrivacyTracking</key>
    <false/>

    <!-- Data Collection: Photos/Videos for grind analysis -->
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>NSPrivacyCollectedDataTypePhotosorVideos</string>
            <key>NSPrivacyCollectedDataTypeLinked</key>
            <true/>
            <key>NSPrivacyCollectedDataTypeTracking</key>
            <false/>
            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
            </array>
        </dict>
    </array>

    <!-- Required Reason APIs -->
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <!-- UserDefaults for app settings -->
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>

        <!-- File timestamps for analysis history -->
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>C617.1</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

### Info.plist Additions (Separate Requirement)
```xml
<!-- Camera access for capturing grind images -->
<key>NSCameraUsageDescription</key>
<string>Coffee Grind Analyzer uses the camera to capture images of your coffee grounds for consistency analysis.</string>

<!-- Photo library write access for saving analysis results -->
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Coffee Grind Analyzer can save your grind analysis results and images to your photo library.</string>
```

**Note**: Info.plist modifications are tracked separately in deployment-timeline.md (Critical Blocker #2).

---

## Key Takeaways

### What Goes in PrivacyInfo.xcprivacy
✅ Required reason API declarations (UserDefaults, file timestamps, disk space, system boot time)
✅ Data collection documentation (photos/videos, location, identifiers, etc.)
✅ Tracking status (true/false)
❌ NOT camera access (use Info.plist NSCameraUsageDescription)
❌ NOT photo library access (use Info.plist NSPhotoLibraryAddUsageDescription)

### What Goes in Info.plist
✅ Camera usage description (NSCameraUsageDescription)
✅ Photo library usage description (NSPhotoLibraryAddUsageDescription or NSPhotoLibraryUsageDescription)
✅ All other traditional permission descriptions
❌ NOT required reason API declarations (those go in PrivacyInfo.xcprivacy)

### Common Pitfalls to Avoid
1. **Confusing Info.plist and privacy manifest**: Camera/photo library are Info.plist-only
2. **Privacy manifest not in target**: Manually verify Target Membership in Xcode File Inspector
3. **Custom reason codes**: Only use Apple's predefined codes (custom codes break validation)
4. **Missing required reason APIs**: Audit codebase for all four API categories

---

## References

**Official Apple Documentation**:
- [Privacy Manifest Files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Adding a Privacy Manifest](https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk)
- [TN3183: Adding Required Reason API Entries](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest)
- [TN3181: Debugging Invalid Privacy Manifest](https://developer.apple.com/documentation/technotes/tn3181-debugging-invalid-privacy-manifest)
- [Describing Data Use in Privacy Manifests](https://developer.apple.com/documentation/bundleresources/describing-data-use-in-privacy-manifests)

**WWDC Sessions**:
- [Get Started with Privacy Manifests - WWDC23](https://developer.apple.com/videos/play/wwdc2023/10060/)

**Enforcement**:
- May 1, 2024: Privacy manifest requirement enforcement began
- Apps without proper declarations are rejected by App Store Connect

---

**Last Updated**: 2026-01-11 | **Status**: Complete
