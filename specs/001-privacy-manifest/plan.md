# Implementation Plan: Complete Privacy Manifest with Required Declarations

**Branch**: `001-privacy-manifest` | **Date**: 2026-01-11 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-privacy-manifest/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Complete the existing PrivacyInfo.xcprivacy file with required declarations for camera and photo library access to ensure App Store Connect submission passes privacy validation. This is a critical blocker (P1) for public release. The implementation focuses on adding proper XML entries with Apple-approved usage reason codes and human-readable descriptions that match the app's actual camera and photo library API usage.

## Technical Context

**Language/Version**: Swift 5.9+, Xcode 26.0+
**Primary Dependencies**: None (native XML file editing, no code dependencies)
**Storage**: PrivacyInfo.xcprivacy XML file in app bundle
**Testing**: Manual validation via App Store Connect upload, Xcode build verification
**Target Platform**: iOS 26.0+
**Project Type**: iOS mobile app (existing SwiftUI project)
**Performance Goals**: N/A (static configuration file, no runtime performance impact)
**Constraints**: Must conform to Apple's PrivacyInfo.xcprivacy schema, must pass App Store validation
**Scale/Scope**: Single XML file modification, 2 privacy declarations (camera + photo library)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Verify compliance with `.specify/memory/constitution.md`:

- [x] **I. SwiftUI-First Architecture**: N/A - This feature only modifies a static XML configuration file, no UI or code changes required
- [x] **II. Test-First Development (MANDATORY)**: Will include validation tests: (1) XML schema validation test, (2) Build verification test, (3) App Store Connect upload validation test
- [x] **III. Performance & Accuracy**: N/A - No runtime performance impact (static bundle resource)
- [x] **IV. Simplicity & Focus**: Fully compliant - Minimal change (XML file only), no abstractions, no code modifications, directly solves App Store submission blocker

**Violations**: None. This is a pure configuration task with no code implementation, only XML editing and validation testing.

**Post-Phase 1 Re-evaluation** (2026-01-11): All principles remain compliant after design phase. No code complexity introduced, only XML schema and validation strategy documented.

## Project Structure

### Documentation (this feature)

```text
specs/001-privacy-manifest/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
Coffee Grind Analyzer/
├── PrivacyInfo.xcprivacy           # TARGET FILE - Empty XML to be filled
├── Info.plist                      # Related file (separate requirement per spec)
├── Camera/
│   └── CoffeeCamera.swift          # Uses AVFoundation camera APIs
└── Models/
    └── CoffeeAnalysisHistoryManager.swift  # Saves to photo library

Coffee Grind AnalyzerTests/
└── PrivacyManifestTests.swift      # NEW - Validation tests for privacy manifest
```

**Structure Decision**: This feature modifies an existing configuration file (`PrivacyInfo.xcprivacy`) rather than adding new source code. The file already exists in the Xcode project at `Coffee Grind Analyzer/PrivacyInfo.xcprivacy` but is currently empty. We will populate it with the required XML declarations. A new test file will be added to verify the manifest is properly formatted and contains all required declarations.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

*No violations - table not needed.*

---

## Phase 0: Research & Analysis

### Research Tasks

This phase will investigate Apple's privacy manifest requirements and determine the exact XML structure and usage reason codes needed.

**Research Areas**:

1. **Apple Privacy Manifest Schema**
   - Official XML schema structure for PrivacyInfo.xcprivacy
   - Required elements and attributes
   - Validation rules enforced by Xcode and App Store Connect

2. **Camera Access Declaration**
   - Correct NSPrivacyAccessedAPIType value for camera/AVFoundation
   - Valid NSPrivacyAccessedAPITypeReasons codes for image capture
   - Human-readable description format

3. **Photo Library Access Declaration**
   - Correct NSPrivacyAccessedAPIType value for photo library
   - Valid NSPrivacyAccessedAPITypeReasons codes for saving user content
   - Human-readable description format

4. **Validation Methods**
   - How to validate XML correctness locally before App Store submission
   - Xcode build-time validation
   - App Store Connect upload validation process

**Output**: Consolidated findings in [research.md](research.md)

---

## Phase 1: Design

### Data Model

The privacy manifest is a structured XML file with specific entities and relationships.

**Entities**:

1. **Privacy Manifest Root**
   - Type: XML plist dictionary
   - Contains: Array of privacy declarations

2. **Privacy Access Declaration**
   - Access Type: NSPrivacyAccessedAPIType (e.g., "NSPrivacyAccessedAPICategoryCamera")
   - Access Reasons: Array of NSPrivacyAccessedAPITypeReasons codes
   - Description: Human-readable string explaining usage

**Output**: Detailed data model in [data-model.md](data-model.md)

### API Contracts

This feature does not involve runtime APIs or endpoints. The "contract" is the XML schema that App Store Connect expects.

**Contract**: Apple's PrivacyInfo.xcprivacy Schema

- **Input**: XML file in app bundle
- **Validation**: Xcode build system and App Store Connect
- **Output**: Pass/fail validation with error messages for non-compliance

**Output**: Schema documentation in [contracts/privacy-manifest-schema.md](contracts/privacy-manifest-schema.md)

### Quickstart

**Output**: Developer guide in [quickstart.md](quickstart.md) covering:
- How to locate and edit PrivacyInfo.xcprivacy
- How to validate changes locally
- How to test via App Store Connect upload
- How to add new privacy declarations in the future

---

## Phase 2: Implementation Tasks

*Generated by `/speckit.tasks` command - not part of this plan document*

**Expected Task Categories**:
1. Write validation tests (TDD - tests first)
2. Edit PrivacyInfo.xcprivacy with camera declaration
3. Edit PrivacyInfo.xcprivacy with photo library declaration
4. Verify tests pass
5. Validate via Xcode build
6. Validate via TestFlight upload

---

## Dependencies

### Internal Dependencies
- Camera functionality (CoffeeCamera.swift) - already implemented
- Photo library saving functionality - already implemented
- Xcode project configuration - PrivacyInfo.xcprivacy already included in app target

### External Dependencies
- Apple Developer documentation: https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
- App Store Connect validation API (accessed via Xcode upload)

### Blocked By
- None (all dependencies already satisfied)

### Blocks
- App Store submission (critical blocker per deployment timeline)
- Public release (cannot proceed without passing App Store review)

---

## Testing Strategy

### Test Categories

1. **XML Schema Validation Test** (Unit)
   - Load PrivacyInfo.xcprivacy from bundle
   - Parse as PropertyList
   - Validate structure matches expected schema
   - Verify required keys exist

2. **Camera Declaration Test** (Unit)
   - Verify camera access type is declared
   - Verify camera access reasons are valid codes
   - Verify description is non-empty

3. **Photo Library Declaration Test** (Unit)
   - Verify photo library access type is declared
   - Verify photo library access reasons are valid codes
   - Verify description is non-empty

4. **Build Validation Test** (Integration)
   - Archive builds successfully without privacy warnings
   - No Xcode privacy manifest errors

5. **App Store Connect Validation Test** (Manual/Integration)
   - Upload to TestFlight succeeds
   - No privacy-related rejection messages
   - Documented in test results

### Test-First Approach

Per Constitution Principle II:
1. Write failing `PrivacyManifestTests.swift` covering all validation scenarios
2. Run tests (expect failures - manifest is currently empty)
3. Edit PrivacyInfo.xcprivacy with correct XML
4. Run tests (expect passes)
5. Upload to App Store Connect for final validation

---

## Risk Assessment

### Low Risk
- **XML syntax errors**: Mitigated by Xcode validation and unit tests
- **Wrong usage reason codes**: Mitigated by research phase finding correct codes from Apple docs

### Medium Risk
- **Apple schema changes**: Privacy manifest is relatively new API. Monitor release notes.
  - *Mitigation*: Follow Apple developer news, validate after iOS/Xcode updates

### No Risk
- **Performance impact**: None - static bundle resource
- **User-facing bugs**: No code changes, only metadata
- **Data migration**: No data model changes

---

## Success Metrics

From spec.md Success Criteria:

- **SC-001**: App submission to App Store Connect completes without privacy-related validation errors or warnings
- **SC-002**: Privacy manifest file passes Apple's automated validation checks with 100% compliance
- **SC-003**: All camera and photo library permission requests display appropriate user-facing explanations when triggered
- **SC-004**: Privacy review by compliance team confirms all API usage is properly declared with no undeclared privacy-sensitive API calls

**Measurement**:
- SC-001/SC-002: Automated via App Store Connect upload response (pass/fail)
- SC-003: Manual testing on device (permission dialogs appear with correct text)
- SC-004: Manual review comparing PrivacyInfo.xcprivacy against CoffeeCamera.swift and CoffeeAnalysisHistoryManager.swift API usage

---

## Timeline Estimate

**Phase 0 (Research)**: 30 minutes
- Review Apple documentation
- Identify correct XML structure and codes

**Phase 1 (Design)**: 15 minutes
- Document data model (simple XML structure)
- Document schema contract

**Phase 2 (Implementation)**: 1 hour
- Write tests: 20 minutes
- Edit XML file: 10 minutes
- Run tests and fix: 10 minutes
- Validate via build: 5 minutes
- Upload to TestFlight: 15 minutes

**Total**: ~2 hours (aligns with deployment-timeline.md estimate of 30 minutes for XML editing + testing overhead)

---

## Rollback Plan

If privacy manifest causes issues:

1. **Revert XML changes**: Git revert to previous empty state
2. **Remove from build**: Exclude PrivacyInfo.xcprivacy from app target (not recommended - delays submission)
3. **Fix forward**: Correct XML based on validation error messages from App Store Connect

**Risk of rollback needed**: Very low - worst case is App Store rejection with clear error messages indicating what to fix.

---

**Last Updated**: 2026-01-11 | **Status**: Phase 0-1 Complete, Ready for Phase 2 (/speckit.tasks)
