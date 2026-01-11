# Data Model: Privacy Manifest Structure

**Feature**: Complete Privacy Manifest with Required Declarations
**Date**: 2026-01-11
**Format**: XML Property List (plist)

## Overview

The privacy manifest is an XML-formatted property list (plist) file with a hierarchical structure. This document describes the logical data model, entity relationships, and validation rules for PrivacyInfo.xcprivacy.

---

## Entity Hierarchy

```
PrivacyManifest (Root Dictionary)
├── NSPrivacyTracking (Boolean)
├── NSPrivacyTrackingDomains (Array of Strings) [Optional]
├── NSPrivacyCollectedDataTypes (Array of DataCollectionDeclarations)
│   └── DataCollectionDeclaration (Dictionary)
│       ├── NSPrivacyCollectedDataType (String, enum)
│       ├── NSPrivacyCollectedDataTypeLinked (Boolean)
│       ├── NSPrivacyCollectedDataTypeTracking (Boolean)
│       └── NSPrivacyCollectedDataTypePurposes (Array of Strings, enum)
└── NSPrivacyAccessedAPITypes (Array of RequiredReasonAPIDeclarations)
    └── RequiredReasonAPIDeclaration (Dictionary)
        ├── NSPrivacyAccessedAPIType (String, enum)
        └── NSPrivacyAccessedAPITypeReasons (Array of Strings, enum)
```

---

## Entity Definitions

### 1. PrivacyManifest (Root)

**Type**: Dictionary (XML plist root element)

**Description**: Top-level container for all privacy declarations

**Required Keys**:
- NSPrivacyTracking (mandatory)
- NSPrivacyCollectedDataTypes (recommended, mandatory if app collects any data)
- NSPrivacyAccessedAPITypes (mandatory if app uses any of the four required reason API categories)

**Optional Keys**:
- NSPrivacyTrackingDomains (only if NSPrivacyTracking is true)

**Validation Rules**:
- Must be valid XML plist with DOCTYPE declaration
- plist version must be "1.0"
- Root element must be `<dict>` containing the four top-level keys

**Relationships**:
- Contains 0-N DataCollectionDeclarations (via NSPrivacyCollectedDataTypes array)
- Contains 0-N RequiredReasonAPIDeclarations (via NSPrivacyAccessedAPITypes array)

---

### 2. NSPrivacyTracking

**Type**: Boolean

**Description**: Declares whether the app tracks users across apps or websites owned by other companies

**Valid Values**:
- `true`: App performs tracking as defined by App Tracking Transparency framework
- `false`: App does not perform tracking

**Validation Rules**:
- Must be present (mandatory key)
- Must be boolean type (not string "true"/"false")

**Business Logic**:
- If true, NSPrivacyTrackingDomains array must be populated
- If false, NSPrivacyTrackingDomains should be omitted or empty

**Coffee Grind Analyzer Value**: `false` (no tracking performed)

---

### 3. NSPrivacyTrackingDomains

**Type**: Array of Strings

**Description**: Internet domains that the app connects to for tracking purposes

**Valid Values**:
- Array of domain strings (e.g., "tracking.example.com")
- Empty array if NSPrivacyTracking is false

**Validation Rules**:
- Optional if NSPrivacyTracking is false
- Mandatory if NSPrivacyTracking is true
- Each string must be a valid domain name

**Coffee Grind Analyzer Value**: Omitted (no tracking)

---

### 4. DataCollectionDeclaration

**Type**: Dictionary

**Description**: Documents a single type of data collected by the app

**Required Keys**:
- NSPrivacyCollectedDataType (String, from enumerated values)
- NSPrivacyCollectedDataTypeLinked (Boolean)
- NSPrivacyCollectedDataTypeTracking (Boolean)
- NSPrivacyCollectedDataTypePurposes (Array of Strings, from enumerated values)

**Validation Rules**:
- All four keys must be present
- NSPrivacyCollectedDataType must be from Apple's approved list
- NSPrivacyCollectedDataTypePurposes must contain at least one valid purpose

**Relationships**:
- Parent: PrivacyManifest (via NSPrivacyCollectedDataTypes array)
- Multiple declarations allowed (one per data type collected)

---

### 5. NSPrivacyCollectedDataType

**Type**: String (Enumerated)

**Description**: Identifies the type of data being collected

**Valid Values** (Subset - Full list in Apple docs):
- `NSPrivacyCollectedDataTypePhotosorVideos` - Photos or videos
- `NSPrivacyCollectedDataTypeName` - User's name
- `NSPrivacyCollectedDataTypeEmailAddress` - Email address
- `NSPrivacyCollectedDataTypePreciseLocation` - Precise location
- `NSPrivacyCollectedDataTypeDeviceID` - Device identifier
- (See research.md for complete list)

**Validation Rules**:
- Must be exact match to Apple's predefined values (case-sensitive)
- Custom values not allowed
- Only one data type per DataCollectionDeclaration

**Coffee Grind Analyzer Value**: `NSPrivacyCollectedDataTypePhotosorVideos`

---

### 6. NSPrivacyCollectedDataTypeLinked

**Type**: Boolean

**Description**: Indicates whether the collected data is linked to the user's identity

**Valid Values**:
- `true`: Data is linked to user (e.g., saved to their personal library)
- `false`: Data is not linked to user (anonymous/aggregated)

**Validation Rules**:
- Must be boolean type

**Coffee Grind Analyzer Value**: `true` (photos saved to user's personal library)

---

### 7. NSPrivacyCollectedDataTypeTracking

**Type**: Boolean

**Description**: Indicates whether the collected data is used for tracking purposes

**Valid Values**:
- `true`: Data used for tracking
- `false`: Data not used for tracking

**Validation Rules**:
- Must be boolean type
- If true, parent PrivacyManifest's NSPrivacyTracking should also be true

**Coffee Grind Analyzer Value**: `false` (images not used for tracking)

---

### 8. NSPrivacyCollectedDataTypePurposes

**Type**: Array of Strings (Enumerated)

**Description**: Documents why the data is collected

**Valid Values** (All six purposes):
1. `NSPrivacyCollectedDataTypePurposeThirdPartyAdvertising` - Third-party advertising
2. `NSPrivacyCollectedDataTypePurposeDeveloperAdvertising` - Developer's own advertising
3. `NSPrivacyCollectedDataTypePurposeAnalytics` - Analytics
4. `NSPrivacyCollectedDataTypePurposeProductPersonalization` - Product personalization
5. `NSPrivacyCollectedDataTypePurposeAppFunctionality` - App functionality
6. `NSPrivacyCollectedDataTypePurposeOther` - Other purposes

**Validation Rules**:
- Must contain at least one purpose
- All values must be from Apple's approved list
- Multiple purposes allowed per data type

**Coffee Grind Analyzer Value**: `[NSPrivacyCollectedDataTypePurposeAppFunctionality]`

---

### 9. RequiredReasonAPIDeclaration

**Type**: Dictionary

**Description**: Documents usage of one of Apple's four "required reason API" categories

**Required Keys**:
- NSPrivacyAccessedAPIType (String, from enumerated values)
- NSPrivacyAccessedAPITypeReasons (Array of Strings, from enumerated values)

**Validation Rules**:
- Both keys must be present
- NSPrivacyAccessedAPIType must be one of the four valid categories
- NSPrivacyAccessedAPITypeReasons must contain at least one valid reason code for that API type

**Relationships**:
- Parent: PrivacyManifest (via NSPrivacyAccessedAPITypes array)
- Multiple declarations allowed (one per API category used)

---

### 10. NSPrivacyAccessedAPIType

**Type**: String (Enumerated)

**Description**: Identifies which category of required reason API is being declared

**Valid Values** (Complete List):
1. `NSPrivacyAccessedAPICategoryFileTimestamp` - File timestamp/metadata APIs
2. `NSPrivacyAccessedAPICategorySystemBootTime` - System boot time calculation APIs
3. `NSPrivacyAccessedAPICategoryDiskSpace` - Disk space query APIs
4. `NSPrivacyAccessedAPICategoryUserDefaults` - UserDefaults APIs

**Validation Rules**:
- Must be exact match to one of the four values
- Custom values not allowed
- Only one API type per RequiredReasonAPIDeclaration

**Coffee Grind Analyzer Values**:
- `NSPrivacyAccessedAPICategoryUserDefaults` (for settings persistence)
- `NSPrivacyAccessedAPICategoryFileTimestamp` (for analysis history sorting)

---

### 11. NSPrivacyAccessedAPITypeReasons

**Type**: Array of Strings (Enumerated)

**Description**: Documents the specific reasons for accessing the API category

**Valid Values**: Depends on NSPrivacyAccessedAPIType (see mappings below)

#### FileTimestamp API Reason Codes:
- `DDA9.1` - Display file timestamps to user
- `C617.1` - Access timestamps of files in app container
- `3B52.1` - Access timestamps of user-selected files
- `0A2A.1` - Third-party SDK wrapper function

#### SystemBootTime API Reason Codes:
- `35F9.1` - Measure time between events in app
- `8FFB.1` - Calculate absolute timestamps
- `3D61.1` - (Additional code)

#### DiskSpace API Reason Codes:
- `85F4.1`, `E174.1`, `7D9E.1`, `B728.1` - (Specific codes for disk space queries)

#### UserDefaults API Reason Codes:
- `CA92.1` - Access app-only UserDefaults
- `1C8F.1` - Access shared UserDefaults (App Groups)
- `C56D.1` - Third-party SDK wrapper function

**Validation Rules**:
- Must contain at least one reason code
- All reason codes must be valid for the parent NSPrivacyAccessedAPIType
- Reason codes from different API categories cannot be mixed

**Coffee Grind Analyzer Values**:
- UserDefaults: `[CA92.1]` (app-only settings)
- FileTimestamp: `[C617.1]` (app container files)

---

## Example Data Model Instance

For Coffee Grind Analyzer:

```
PrivacyManifest {
  NSPrivacyTracking: false
  NSPrivacyTrackingDomains: <omitted>

  NSPrivacyCollectedDataTypes: [
    DataCollectionDeclaration {
      NSPrivacyCollectedDataType: "NSPrivacyCollectedDataTypePhotosorVideos"
      NSPrivacyCollectedDataTypeLinked: true
      NSPrivacyCollectedDataTypeTracking: false
      NSPrivacyCollectedDataTypePurposes: ["NSPrivacyCollectedDataTypePurposeAppFunctionality"]
    }
  ]

  NSPrivacyAccessedAPITypes: [
    RequiredReasonAPIDeclaration {
      NSPrivacyAccessedAPIType: "NSPrivacyAccessedAPICategoryUserDefaults"
      NSPrivacyAccessedAPITypeReasons: ["CA92.1"]
    },
    RequiredReasonAPIDeclaration {
      NSPrivacyAccessedAPIType: "NSPrivacyAccessedAPICategoryFileTimestamp"
      NSPrivacyAccessedAPITypeReasons: ["C617.1"]
    }
  ]
}
```

---

## Cardinality Rules

| Entity | Parent | Cardinality | Notes |
|--------|--------|-------------|-------|
| PrivacyManifest | (root) | 1 | Exactly one per file |
| NSPrivacyTracking | PrivacyManifest | 1 | Mandatory key |
| NSPrivacyTrackingDomains | PrivacyManifest | 0..1 | Optional unless tracking=true |
| NSPrivacyCollectedDataTypes | PrivacyManifest | 0..N | Recommended if app collects data |
| DataCollectionDeclaration | NSPrivacyCollectedDataTypes | 0..N | One per data type collected |
| NSPrivacyAccessedAPITypes | PrivacyManifest | 0..N | Mandatory if using required reason APIs |
| RequiredReasonAPIDeclaration | NSPrivacyAccessedAPITypes | 0..4 | Max four (one per API category) |

---

## State Transitions

Privacy manifest is a **static configuration file** with no runtime state transitions. However, it has lifecycle states:

### Development Lifecycle States

1. **Empty**: File exists but contains no declarations (current state)
2. **Draft**: Declarations added but not validated
3. **Validated (Local)**: Passes plutil syntax check
4. **Validated (Xcode)**: Passes Xcode Privacy Report generation
5. **Validated (App Store)**: Passes App Store Connect upload validation
6. **Published**: Included in released app on App Store

### Validation State Machine

```
Empty
  ↓ (add declarations)
Draft
  ↓ (plutil -lint)
Syntax Valid / Syntax Invalid → (fix errors) → Draft
  ↓ (Xcode Privacy Report)
Semantically Valid / Semantically Invalid → (fix values) → Draft
  ↓ (App Store Connect upload)
App Store Valid / App Store Rejected → (fix issues) → Draft
  ↓ (app approval)
Published
```

---

## Validation Rules Summary

### File-Level Validation
- ✅ Valid XML syntax
- ✅ Valid plist structure with DOCTYPE
- ✅ Root element is `<dict>`
- ✅ Contains NSPrivacyTracking key

### Data Collection Validation
- ✅ Each DataCollectionDeclaration has all four required keys
- ✅ NSPrivacyCollectedDataType from approved list
- ✅ NSPrivacyCollectedDataTypePurposes has at least one valid purpose
- ✅ Boolean fields are actual booleans, not strings

### Required Reason API Validation
- ✅ Each RequiredReasonAPIDeclaration has both required keys
- ✅ NSPrivacyAccessedAPIType is one of four valid categories
- ✅ NSPrivacyAccessedAPITypeReasons codes are valid for the API type
- ✅ No duplicate API type declarations

### Business Logic Validation
- ✅ If NSPrivacyTracking=true, NSPrivacyTrackingDomains is populated
- ✅ If NSPrivacyCollectedDataTypeTracking=true, NSPrivacyTracking should be true
- ✅ All declared API categories match actual codebase usage

---

## Schema Version

**Apple Privacy Manifest Schema Version**: 1.0 (as of 2026-01-11)

**Enforcement Date**: May 1, 2024 (required reason API declarations mandatory)

**Compatibility**: iOS 12.0+, iPadOS 12.0+, macOS 10.14+, tvOS 12.0+, watchOS 5.0+

---

**Last Updated**: 2026-01-11 | **Status**: Complete
