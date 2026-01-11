# Contract: Apple PrivacyInfo.xcprivacy Schema

**Feature**: Complete Privacy Manifest with Required Declarations
**Date**: 2026-01-11
**Type**: XML Schema Contract (not a runtime API)

## Contract Overview

This document defines the "contract" between the Coffee Grind Analyzer app and Apple's App Store Connect validation system. Unlike traditional API contracts (REST endpoints, GraphQL schemas), this is a **file format contract**—the structure and content that Apple expects in PrivacyInfo.xcprivacy files.

---

## Contract Parties

**Provider**: Coffee Grind Analyzer app (supplies PrivacyInfo.xcprivacy file)

**Consumer**: Apple's validation systems:
1. Xcode build system (compile-time validation)
2. Xcode Privacy Report generator (semantic validation)
3. App Store Connect upload API (submission-time validation)

---

## Contract Specification

### Input

**File**: `Coffee Grind Analyzer/PrivacyInfo.xcprivacy`

**Format**: XML Property List (plist) version 1.0

**Encoding**: UTF-8

**Location**: Must be included in app target's bundle resources

**Size Constraints**: No documented limit (typical files: 1-10 KB)

---

### Expected Structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
         "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Mandatory: Tracking declaration -->
    <key>NSPrivacyTracking</key>
    <[boolean]/>

    <!-- Optional: Tracking domains (mandatory if tracking=true) -->
    <key>NSPrivacyTrackingDomains</key>
    <array>
        <string>[domain]</string>
    </array>

    <!-- Recommended: Data collection -->
    <key>NSPrivacyCollectedDataTypes</key>
    <array>
        <dict>
            <key>NSPrivacyCollectedDataType</key>
            <string>[enumerated_value]</string>

            <key>NSPrivacyCollectedDataTypeLinked</key>
            <[boolean]/>

            <key>NSPrivacyCollectedDataTypeTracking</key>
            <[boolean]/>

            <key>NSPrivacyCollectedDataTypePurposes</key>
            <array>
                <string>[enumerated_value]</string>
            </array>
        </dict>
    </array>

    <!-- Mandatory if using required reason APIs -->
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>[enumerated_value]</string>

            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>[reason_code]</string>
            </array>
        </dict>
    </array>
</dict>
</plist>
```

---

## Validation Rules (Contract Guarantees)

### Syntax Validation (Xcode Build)

**Rule 1**: Valid XML syntax
- **Check**: Well-formed XML with proper tag closure
- **Error**: Build warning/error if malformed
- **Tool**: `plutil -lint PrivacyInfo.xcprivacy`

**Rule 2**: Valid plist structure
- **Check**: Conforms to Apple's plist DTD
- **Error**: Build warning if DOCTYPE missing or incorrect
- **Validation**: plist version="1.0" attribute present

**Rule 3**: Root element is dictionary
- **Check**: Top-level element is `<dict>`, not `<array>` or other
- **Error**: Build error if root type incorrect

---

### Semantic Validation (Xcode Privacy Report)

**Rule 4**: NSPrivacyTracking is boolean
- **Check**: Value is `<true/>` or `<false/>`, not `<string>true</string>`
- **Error**: Privacy Report generation fails

**Rule 5**: Enumerated values from approved lists
- **Check**: All NSPrivacyCollectedDataType values are from Apple's list
- **Error**: Unknown data type shows as warning in Privacy Report
- **Impact**: App Store privacy label may be incorrect

**Rule 6**: Required reason codes valid for API type
- **Check**: Reason codes match the API category
  - Example: CA92.1 is valid for UserDefaults, invalid for FileTimestamp
- **Error**: Validation failure, app rejected

**Rule 7**: Consistency between keys
- **Check**: If NSPrivacyTracking=true, NSPrivacyTrackingDomains exists and non-empty
- **Error**: Warning in Privacy Report

---

### App Store Connect Validation (Upload)

**Rule 8**: Required reason APIs declared (ITMS-91053)
- **Check**: If app uses UserDefaults, FileTimestamp, DiskSpace, or SystemBootTime APIs, corresponding NSPrivacyAccessedAPITypes entry exists
- **Error**: ITMS-91053 "Missing API declaration"
- **Enforcement**: Mandatory since May 1, 2024
- **Consequence**: App submission rejected

**Rule 9**: Reason codes are valid (ITMS-91056)
- **Check**: All reason codes are from Apple's approved lists
- **Error**: ITMS-91056 "Invalid privacy manifest"
- **Consequence**: App submission rejected

**Rule 10**: File is included in bundle
- **Check**: PrivacyInfo.xcprivacy exists in app's main bundle
- **Error**: ITMS error if file missing from bundle resources
- **Consequence**: App submission rejected

**Rule 11**: No conflicting declarations
- **Check**: Same API type not declared multiple times
- **Error**: Validation warning or rejection

---

## Output (Validation Response)

### Success Response

**Xcode Build**:
- Exit code: 0
- Output: No privacy-related warnings or errors
- Privacy Report: Successfully generated

**App Store Connect Upload**:
- HTTP 200 response
- Status: "Processing" → "Ready for Review"
- No ITMS error codes in email notification

---

### Failure Responses

#### ITMS-91053: Missing API Declaration
```
ITMS-91053: Missing API declaration - Your app's code in the
"Coffee Grind Analyzer" file references one or more APIs that
require reasons, including the following API categories:
NSPrivacyAccessedAPICategoryUserDefaults. While no action is
required at this time, starting May 1, 2024, when you upload a
new app or app update, you must include a NSPrivacyAccessedAPITypes
array in your app's privacy manifest to provide approved reasons
for these APIs used by your app's code.
```

**Cause**: App uses required reason API without declaration

**Fix**: Add corresponding NSPrivacyAccessedAPITypes entry

---

#### ITMS-90683: Missing Purpose String
```
ITMS-90683: Missing Purpose String in Info.plist - Your app's code
references one or more APIs that access sensitive user data. The
app's Info.plist file should contain a NSCameraUsageDescription key
with a user-facing purpose string explaining clearly and completely
why your app needs the data.
```

**Cause**: NSCameraUsageDescription missing from Info.plist (separate but related requirement)

**Fix**: Add Info.plist key with user-facing description

---

#### ITMS-91056: Invalid Privacy Manifest
```
ITMS-91056: Invalid privacy manifest - The PrivacyInfo.xcprivacy
file from the following path is invalid: "Frameworks/YourFramework.framework/
PrivacyInfo.xcprivacy". Unable to extract contents.
```

**Cause**: Malformed XML, invalid plist structure, or invalid enumerated values

**Fix**: Validate with `plutil -lint`, check values against approved lists

---

#### ITMS-91064: Invalid Tracking Information
```
ITMS-91064: Invalid tracking information - The PrivacyInfo.xcprivacy
for your app contains tracking information that is not valid.
```

**Cause**: NSPrivacyTracking=true but NSPrivacyTrackingDomains missing or malformed

**Fix**: Add valid NSPrivacyTrackingDomains array or set NSPrivacyTracking=false

---

## Contract Versioning

**Current Schema Version**: 1.0 (as of 2026-01-11)

**Backward Compatibility**: Apps built with older Xcode versions (pre-Xcode 15) are not required to include privacy manifests, but are strongly encouraged to add them

**Forward Compatibility**: Apple may add new keys or enumerated values in future iOS/Xcode versions. Unknown keys are ignored by older systems.

**Breaking Changes**: Apple announces breaking changes at WWDC with transition periods (typically 6-12 months before enforcement)

---

## Contract Testing

### Test 1: Syntax Validation
```bash
plutil -lint Coffee\ Grind\ Analyzer/PrivacyInfo.xcprivacy
```

**Expected Output**: File is valid plist

**Pass Criteria**: Exit code 0, no error messages

---

### Test 2: Privacy Report Generation
```
1. Xcode → Product → Archive
2. Right-click archive → Generate Privacy Report
```

**Expected Output**: Privacy Report PDF generated successfully

**Pass Criteria**:
- Report contains "Photos or Videos" data collection
- Report shows UserDefaults and File Timestamp API usage
- No unknown/invalid values flagged

---

### Test 3: App Store Connect Upload
```
1. Xcode → Product → Archive
2. Organizer → Distribute App → App Store Connect
3. Upload with Xcode 26+
```

**Expected Output**: Upload succeeds, no ITMS-910XX errors

**Pass Criteria**:
- Upload completes successfully
- Email confirmation from Apple with no warnings
- TestFlight build appears in App Store Connect

---

### Test 4: Bundle Verification
```bash
# Build and check if privacy manifest is in bundle
xcodebuild -project "Coffee Grind Analyzer.xcodeproj" \
           -scheme "Coffee Grind Analyzer" \
           -configuration Release \
           archive -archivePath build/CGAArchive.xcarchive

# Check archive contents
ls -la build/CGAArchive.xcarchive/Products/Applications/Coffee\ Grind\ Analyzer.app/PrivacyInfo.xcprivacy
```

**Expected Output**: PrivacyInfo.xcprivacy file exists in .app bundle

**Pass Criteria**: File present with non-zero size (~1-2 KB)

---

## Contract Compliance Checklist

- [ ] **File exists**: `Coffee Grind Analyzer/PrivacyInfo.xcprivacy` created
- [ ] **File included in target**: Target Membership checkbox checked in Xcode
- [ ] **Valid XML**: Passes `plutil -lint` validation
- [ ] **Valid plist**: DOCTYPE and version="1.0" present
- [ ] **NSPrivacyTracking declared**: Boolean value present
- [ ] **Data collection documented**: NSPrivacyCollectedDataTypes populated for photos/videos
- [ ] **Required APIs declared**: UserDefaults and FileTimestamp in NSPrivacyAccessedAPITypes
- [ ] **Reason codes valid**: CA92.1 for UserDefaults, C617.1 for FileTimestamp
- [ ] **Privacy Report generates**: Xcode successfully creates Privacy Report PDF
- [ ] **Upload succeeds**: App Store Connect accepts upload without ITMS-910XX errors

---

## Reference Implementation

See [research.md](../research.md) for complete XML example matching this contract specification.

---

## Contract Authority

**Official Specification**: [Privacy Manifest Files - Apple Developer Documentation](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)

**Validation Reference**: [TN3181: Debugging an Invalid Privacy Manifest](https://developer.apple.com/documentation/technotes/tn3181-debugging-invalid-privacy-manifest)

**Required Reason APIs**: [TN3183: Adding Required Reason API Entries](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest)

---

**Last Updated**: 2026-01-11 | **Status**: Complete
