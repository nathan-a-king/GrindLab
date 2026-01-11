# Quickstart Guide: Implementing Privacy Manifest

**Feature**: Complete Privacy Manifest with Required Declarations
**Audience**: Developers implementing or maintaining privacy manifest
**Time to Complete**: 15-30 minutes

## Prerequisites

- Xcode 26.0+ installed
- Coffee Grind Analyzer project open in Xcode
- Understanding of basic XML/plist editing

---

## Step 1: Locate the Privacy Manifest File

**Path**: `Coffee Grind Analyzer/PrivacyInfo.xcprivacy`

**Verification**:
1. Open Xcode with Coffee Grind Analyzer project
2. In Project Navigator (⌘1), search for "PrivacyInfo.xcprivacy"
3. File should be visible in the "Coffee Grind Analyzer" folder

**If file is missing**: Create new file → Property List → name it "PrivacyInfo.xcprivacy"

---

## Step 2: Verify Target Membership

**Critical Step**: Privacy manifest must be included in app target's bundle resources

**How to verify**:
1. Select PrivacyInfo.xcprivacy in Project Navigator
2. Open File Inspector (⌥⌘1)
3. Check "Target Membership" section
4. **Ensure "Coffee Grind Analyzer" checkbox is checked**

**If unchecked**: Check the box to include file in build

**Common Mistake**: Unlike Swift files, plist files don't automatically get target membership—must be manually verified.

---

## Step 3: Edit Privacy Manifest Content

**Option A: Xcode GUI Editor** (Recommended for beginners)

1. Select PrivacyInfo.xcprivacy
2. Xcode shows property list editor (table view)
3. Add keys using "+" button or right-click → Add Row

**Option B: Source Code Editor** (Recommended for advanced users)

1. Right-click PrivacyInfo.xcprivacy → Open As → Source Code
2. Paste complete XML from template below
3. Save file (⌘S)

---

### Template: Complete Privacy Manifest

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Tracking Declaration -->
    <key>NSPrivacyTracking</key>
    <false/>

    <!-- Data Collection -->
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
        <!-- UserDefaults -->
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array>
                <string>CA92.1</string>
            </array>
        </dict>

        <!-- File Timestamps -->
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

**Usage**: Copy entire XML block above and paste into PrivacyInfo.xcprivacy (Open As → Source Code)

---

## Step 4: Validate Syntax Locally

**Terminal Command**:
```bash
cd /Users/nate/Developer/GrindLab
plutil -lint "Coffee Grind Analyzer/PrivacyInfo.xcprivacy"
```

**Expected Output**:
```
Coffee Grind Analyzer/PrivacyInfo.xcprivacy: OK
```

**If error appears**:
- Check XML syntax (missing `<`, `>`, or quotes)
- Verify DOCTYPE declaration is present
- Ensure plist version="1.0"

**Fix Command** (auto-format):
```bash
plutil -convert xml1 "Coffee Grind Analyzer/PrivacyInfo.xcprivacy"
```

---

## Step 5: Build and Test

**Build the app**:
1. Xcode → Product → Clean Build Folder (⌘⇧K)
2. Xcode → Product → Build (⌘B)

**Expected Result**: Build succeeds with no privacy-related warnings or errors

**Common Build Issues**:

| Issue | Cause | Fix |
|-------|-------|-----|
| "PrivacyInfo.xcprivacy not found" | File not in target | Check Target Membership (Step 2) |
| "Invalid plist" | XML syntax error | Run `plutil -lint` and fix errors |
| Build warning | Unknown key or value | Verify keys match template exactly |

---

## Step 6: Generate Privacy Report

**Steps**:
1. Xcode → Product → Archive (wait for archive to complete)
2. Organizer window appears automatically
3. Select your archive
4. Right-click (Control-click) the archive
5. Select "Generate Privacy Report"

**Expected Output**: Privacy Report PDF opens showing:
- **Data Types Collected**: Photos or Videos
- **Data Use**: App Functionality
- **API Categories**: UserDefaults, File Timestamp

**Verification Checklist**:
- [ ] Photos/Videos appears under "Data Types Collected"
- [ ] Purpose listed as "App Functionality"
- [ ] "Tracking" is marked as "No"
- [ ] UserDefaults and File Timestamp appear under "Accessed API Types"
- [ ] No unknown/invalid entries flagged

---

## Step 7: Upload to App Store Connect (Final Validation)

**Prerequisites**:
- Archive created (Step 6)
- App Store Connect app record created
- Valid provisioning profile

**Steps**:
1. Organizer → Select your archive
2. Click "Distribute App"
3. Select "App Store Connect" → Next
4. Select "Upload" → Next
5. Follow prompts (signing, options)
6. Click "Upload"

**Expected Result**: Upload succeeds with no ITMS error codes

**Common Upload Errors**:

| Error Code | Meaning | Fix |
|------------|---------|-----|
| ITMS-91053 | Missing required reason API | Add missing API to NSPrivacyAccessedAPITypes |
| ITMS-91056 | Invalid privacy manifest | Validate with `plutil -lint` and Privacy Report |
| ITMS-90683 | Missing Info.plist keys | Add NSCameraUsageDescription (separate requirement) |
| ITMS-91064 | Invalid tracking info | Verify NSPrivacyTracking and NSPrivacyTrackingDomains |

---

## Step 8: Verify in TestFlight

**Timeline**: 5-30 minutes after upload

**Steps**:
1. Log in to App Store Connect
2. Go to "TestFlight" tab
3. Wait for build processing to complete
4. Install build on test device via TestFlight

**On-Device Verification**:
1. Launch app
2. Tap camera feature (triggers permission request)
3. **Verify**: Permission dialog shows correct description from Info.plist
4. Grant permission
5. Capture analysis image
6. Save to photo library (triggers photo library permission)
7. **Verify**: Permission dialog shows correct description

**Pass Criteria**:
- App launches without crashes
- Permission dialogs appear with custom descriptions
- No privacy-related warnings in device console

---

## Troubleshooting

### Issue: "Privacy manifest not taking effect"

**Symptoms**: Upload succeeds but privacy manifest seems ignored

**Causes & Fixes**:
1. **Cached build**: Clean build folder (⌘⇧K) and rebuild
2. **Old archive**: Create new archive after editing manifest
3. **Multiple manifests**: Check for conflicting manifests in frameworks (should have only one in app target)

---

### Issue: "Unknown API type" in Privacy Report

**Symptoms**: Privacy Report shows warning about unknown NSPrivacyAccessedAPIType

**Causes**:
- Typo in API type string (e.g., "UserDefaults" instead of "NSPrivacyAccessedAPICategoryUserDefaults")
- Extra whitespace in XML

**Fix**: Compare your XML against template character-by-character

---

### Issue: "Reason code invalid"

**Symptoms**: App Store Connect rejects upload with ITMS-91056

**Causes**:
- Wrong reason code for API type (e.g., DDA9.1 used for UserDefaults instead of CA92.1)
- Custom reason code not from Apple's list

**Fix**: See [research.md](../research.md) for complete list of valid reason codes per API type

---

## Adding New Privacy Declarations (Future)

### When to Update Privacy Manifest

**Triggers**:
1. App starts using new required reason API (UserDefaults, FileTimestamp, DiskSpace, SystemBootTime)
2. App collects new type of user data (location, contacts, etc.)
3. App starts performing tracking (NSPrivacyTracking changes to true)
4. Apple announces new required reason API categories

---

### How to Add New Required Reason API

**Example**: Adding disk space API declaration

1. **Identify API category**: DiskSpace APIs → `NSPrivacyAccessedAPICategoryDiskSpace`
2. **Choose reason code**: See [Apple's documentation](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api) for valid codes
3. **Add to manifest**:

```xml
<dict>
    <key>NSPrivacyAccessedAPIType</key>
    <string>NSPrivacyAccessedAPICategoryDiskSpace</string>
    <key>NSPrivacyAccessedAPITypeReasons</key>
    <array>
        <string>E174.1</string>
    </array>
</dict>
```

4. **Re-validate**: Run plutil, generate Privacy Report, test upload

---

### How to Add New Data Collection Type

**Example**: Adding location data collection

```xml
<dict>
    <key>NSPrivacyCollectedDataType</key>
    <string>NSPrivacyCollectedDataTypePreciseLocation</string>
    <key>NSPrivacyCollectedDataTypeLinked</key>
    <true/>
    <key>NSPrivacyCollectedDataTypeTracking</key>
    <false/>
    <key>NSPrivacyCollectedDataTypePurposes</key>
    <array>
        <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
    </array>
</dict>
```

**Don't forget**: Also add `NSLocationWhenInUseUsageDescription` to Info.plist

---

## Quick Reference

### Files to Edit

| File | Purpose | Required Changes |
|------|---------|------------------|
| PrivacyInfo.xcprivacy | Privacy manifest | Add NSPrivacy* declarations |
| Info.plist | Permission descriptions | Add NSCameraUsageDescription, NSPhotoLibraryAddUsageDescription (separate requirement) |

### Validation Commands

```bash
# Syntax validation
plutil -lint "Coffee Grind Analyzer/PrivacyInfo.xcprivacy"

# Auto-format
plutil -convert xml1 "Coffee Grind Analyzer/PrivacyInfo.xcprivacy"

# View in terminal
cat "Coffee Grind Analyzer/PrivacyInfo.xcprivacy"
```

### Xcode Shortcuts

- Clean Build Folder: ⌘⇧K
- Build: ⌘B
- Archive: Product → Archive (no shortcut)
- Organizer: Window → Organizer (⌘⌥⇧O)

---

## Resources

**Official Documentation**:
- [Privacy Manifest Files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [TN3183: Adding Required Reason API Entries](https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest)
- [TN3181: Debugging Invalid Privacy Manifest](https://developer.apple.com/documentation/technotes/tn3181-debugging-invalid-privacy-manifest)

**Internal Documentation**:
- [research.md](../research.md) - Complete research findings with all valid codes
- [data-model.md](../data-model.md) - Privacy manifest data structure reference
- [contracts/privacy-manifest-schema.md](../contracts/privacy-manifest-schema.md) - Validation contract specification

---

## Success Checklist

- [ ] PrivacyInfo.xcprivacy file exists and is in app target
- [ ] XML syntax validates with `plutil -lint`
- [ ] Build succeeds with no privacy warnings
- [ ] Privacy Report generates successfully
- [ ] Upload to App Store Connect succeeds (no ITMS-910XX errors)
- [ ] TestFlight build appears in App Store Connect
- [ ] Permission dialogs show correct descriptions on device

**Estimated Time**: 15-30 minutes for initial implementation

---

**Last Updated**: 2026-01-11 | **Status**: Complete
