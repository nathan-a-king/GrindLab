---
description: "Implementation tasks for privacy manifest feature"
---

# Tasks: Complete Privacy Manifest with Required Declarations

**Input**: Design documents from `/specs/001-privacy-manifest/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: This feature follows Test-First Development (TDD) per Constitution Principle II. Tests MUST be written BEFORE implementation and MUST fail initially.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **iOS Project**: `Coffee Grind Analyzer/` (main app target)
- **Tests**: `Coffee Grind AnalyzerTests/` (test target)
- **Specs**: `/Users/nate/Developer/GrindLab/specs/001-privacy-manifest/`

---

## Phase 1: Setup (No Dependencies)

**Purpose**: Verify prerequisites and prepare for implementation

- [ ] T001 Verify PrivacyInfo.xcprivacy file exists at `Coffee Grind Analyzer/PrivacyInfo.xcprivacy`
- [ ] T002 Verify PrivacyInfo.xcprivacy has Target Membership in app target (Xcode File Inspector)
- [ ] T003 Verify current file is empty or has placeholder content (read current state)

**Checkpoint**: Prerequisites verified, ready for test-first implementation

---

## Phase 2: Foundational (Test Framework Setup)

**Purpose**: Create test infrastructure that ALL user stories will use for validation

**⚠️ CRITICAL**: Tests MUST be created before ANY XML editing per Constitution Principle II (Test-First Development)

- [ ] T004 Create `Coffee Grind AnalyzerTests/PrivacyManifestTests.swift` test file
- [ ] T005 Add test imports: `XCTest`, `@testable import Coffee_Grind_Analyzer`
- [ ] T006 Create `PrivacyManifestTests` class inheriting from `XCTestCase`
- [ ] T007 Add helper method `loadPrivacyManifest() -> [String: Any]?` to parse PrivacyInfo.xcprivacy from bundle

**Checkpoint**: Test framework ready - user story implementation can now begin

---

## Phase 3: User Story 1 - App Store Submission Passes Privacy Validation (Priority: P1) 🎯 MVP

**Goal**: Privacy manifest contains all required declarations to pass App Store Connect validation without privacy-related rejections

**Independent Test**: Upload app to App Store Connect and verify no ITMS-91053, ITMS-91056, or other privacy-related errors appear

### Tests for User Story 1 (TDD - Red Phase)

> **NOTE: Write these tests FIRST, run them (expect FAILURES), then implement**

- [ ] T008 [P] [US1] Write `testPrivacyManifestFileExists()` - verify PrivacyInfo.xcprivacy loads from bundle
- [ ] T009 [P] [US1] Write `testPrivacyManifestIsValidPlist()` - verify file parses as valid PropertyList
- [ ] T010 [P] [US1] Write `testNSPrivacyTrackingExists()` - verify NSPrivacyTracking key exists and is boolean
- [ ] T011 [P] [US1] Write `testNSPrivacyCollectedDataTypesExists()` - verify NSPrivacyCollectedDataTypes array exists
- [ ] T012 [P] [US1] Write `testPhotoVideoDataCollectionDeclared()` - verify photos/videos data type is declared with correct purpose
- [ ] T013 [P] [US1] Write `testNSPrivacyAccessedAPITypesExists()` - verify NSPrivacyAccessedAPITypes array exists
- [ ] T014 [P] [US1] Write `testUserDefaultsAPIDeclared()` - verify UserDefaults API type with CA92.1 reason code
- [ ] T015 [P] [US1] Write `testFileTimestampAPIDeclared()` - verify FileTimestamp API type with C617.1 reason code

**Run Tests**: Execute `cmd+U` in Xcode - all tests should FAIL (Red phase complete)

### Implementation for User Story 1 (TDD - Green Phase)

- [ ] T016 [US1] Open `Coffee Grind Analyzer/PrivacyInfo.xcprivacy` in Xcode (Open As → Source Code)
- [ ] T017 [US1] Add XML declaration and DOCTYPE to PrivacyInfo.xcprivacy (copy from `specs/001-privacy-manifest/quickstart.md` Step 3)
- [ ] T018 [US1] Add NSPrivacyTracking key with value `<false/>` to PrivacyInfo.xcprivacy
- [ ] T019 [US1] Add NSPrivacyCollectedDataTypes array with photos/videos declaration (NSPrivacyCollectedDataTypePhotosorVideos, linked=true, tracking=false, purpose=AppFunctionality)
- [ ] T020 [US1] Add NSPrivacyAccessedAPITypes array to PrivacyInfo.xcprivacy
- [ ] T021 [US1] Add UserDefaults API declaration with NSPrivacyAccessedAPICategoryUserDefaults and reason code CA92.1
- [ ] T022 [US1] Add FileTimestamp API declaration with NSPrivacyAccessedAPICategoryFileTimestamp and reason code C617.1
- [ ] T023 [US1] Save PrivacyInfo.xcprivacy file

**Run Tests**: Execute `cmd+U` in Xcode - all User Story 1 tests should now PASS (Green phase complete)

### Validation for User Story 1

- [ ] T024 [US1] Run `plutil -lint "Coffee Grind Analyzer/PrivacyInfo.xcprivacy"` - verify syntax validation passes
- [ ] T025 [US1] Build project (cmd+B) - verify no privacy manifest warnings or errors
- [ ] T026 [US1] Archive project (Product → Archive) and generate Privacy Report - verify report shows photos/videos, UserDefaults, FileTimestamp
- [ ] T027 [US1] Upload archive to App Store Connect (TestFlight) - verify no ITMS-91053 or ITMS-91056 errors

**Checkpoint**: User Story 1 complete - App Store submission passes privacy validation ✅

---

## Phase 4: User Story 2 - Users Understand Data Privacy (Priority: P2)

**Goal**: Users see clear, transparent explanations of why the app needs camera and photo access when permission dialogs appear

**Independent Test**: Install app on device, trigger camera and photo library permissions, verify clear descriptions appear in system dialogs

**Note**: This user story is tracked separately in deployment-timeline.md as "Missing Info.plist Permissions" (Critical Blocker #2). Implementation requires editing Info.plist, not PrivacyInfo.xcprivacy.

### Tests for User Story 2 (TDD - Red Phase)

> **NOTE: These tests verify Info.plist keys exist (separate file from User Story 1)**

- [ ] T028 [P] [US2] Write `testNSCameraUsageDescriptionExists()` in PrivacyManifestTests.swift - verify Info.plist contains NSCameraUsageDescription key
- [ ] T029 [P] [US2] Write `testNSCameraUsageDescriptionNotEmpty()` - verify description is non-empty string
- [ ] T030 [P] [US2] Write `testNSPhotoLibraryAddUsageDescriptionExists()` - verify Info.plist contains NSPhotoLibraryAddUsageDescription key
- [ ] T031 [P] [US2] Write `testNSPhotoLibraryAddUsageDescriptionNotEmpty()` - verify description is non-empty string

**Run Tests**: Execute `cmd+U` - all User Story 2 tests should FAIL (Red phase)

### Implementation for User Story 2

- [ ] T032 [US2] Open `Coffee Grind Analyzer/Info.plist` in Xcode
- [ ] T033 [US2] Add NSCameraUsageDescription key with value "Coffee Grind Analyzer uses the camera to capture images of your coffee grounds for consistency analysis."
- [ ] T034 [US2] Add NSPhotoLibraryAddUsageDescription key with value "Coffee Grind Analyzer can save your grind analysis results and images to your photo library."
- [ ] T035 [US2] Save Info.plist file

**Run Tests**: Execute `cmd+U` - all User Story 2 tests should now PASS (Green phase)

### On-Device Validation for User Story 2

- [ ] T036 [US2] Install build on test device via Xcode (cmd+R)
- [ ] T037 [US2] Navigate to camera feature in app (triggers NSCameraUsageDescription permission dialog)
- [ ] T038 [US2] Verify permission dialog shows custom description from Info.plist (not generic iOS message)
- [ ] T039 [US2] Grant camera permission, capture analysis, trigger save to photo library
- [ ] T040 [US2] Verify photo library permission dialog shows custom description from Info.plist

**Checkpoint**: User Story 2 complete - Users understand data privacy through clear permission descriptions ✅

---

## Phase 5: User Story 3 - Privacy Compliance Verification (Priority: P3)

**Goal**: Compliance reviewers can verify all privacy-sensitive API usage is properly declared and documented for audit readiness

**Independent Test**: Review privacy manifest against checklist of all privacy-sensitive APIs, verify completeness and correctness

### Tests for User Story 3 (Comprehensive Validation)

> **NOTE: These tests verify compliance against Apple's schema and actual codebase API usage**

- [ ] T041 [P] [US3] Write `testAllRequiredKeysPresent()` in PrivacyManifestTests.swift - verify all 3 top-level keys exist (NSPrivacyTracking, NSPrivacyCollectedDataTypes, NSPrivacyAccessedAPITypes)
- [ ] T042 [P] [US3] Write `testDataCollectionLinkedFieldsCorrect()` - verify photos/videos linked=true, tracking=false
- [ ] T043 [P] [US3] Write `testDataCollectionPurposeValid()` - verify purpose is NSPrivacyCollectedDataTypePurposeAppFunctionality (exact string match)
- [ ] T044 [P] [US3] Write `testAPITypeEnumValuesCorrect()` - verify API types use exact Apple enum values (NSPrivacyAccessedAPICategoryUserDefaults, NSPrivacyAccessedAPICategoryFileTimestamp)
- [ ] T045 [P] [US3] Write `testReasonCodesMatchAPITypes()` - verify CA92.1 is in UserDefaults declaration, C617.1 is in FileTimestamp declaration
- [ ] T046 [P] [US3] Write `testNoUnknownKeys()` - verify no custom/invalid keys exist in manifest

**Run Tests**: Execute `cmd+U` - tests should PASS if User Story 1 implementation was correct

### Documentation for User Story 3

- [ ] T047 [US3] Create `specs/001-privacy-manifest/compliance-checklist.md` documenting all API usages mapped to manifest declarations
- [ ] T048 [US3] Document camera API usage: AVFoundation in `Coffee Grind Analyzer/Camera/CoffeeCamera.swift` → NOT in required reason APIs (Info.plist only)
- [ ] T049 [US3] Document photo library API usage: Photo library save in `Coffee Grind Analyzer/Models/CoffeeAnalysisHistoryManager.swift` → NOT in required reason APIs (Info.plist only)
- [ ] T050 [US3] Document UserDefaults usage: SettingsPersistence.swift → NSPrivacyAccessedAPICategoryUserDefaults with CA92.1
- [ ] T051 [US3] Document file timestamp usage: CoffeeAnalysisHistoryManager.swift file operations → NSPrivacyAccessedAPICategoryFileTimestamp with C617.1
- [ ] T052 [US3] Add "Last Reviewed" date to compliance checklist

### Compliance Validation for User Story 3

- [ ] T053 [US3] Run all PrivacyManifestTests.swift tests - verify 100% pass rate
- [ ] T054 [US3] Compare compliance-checklist.md against PrivacyInfo.xcprivacy - verify all documented API usages are declared
- [ ] T055 [US3] Review Privacy Report PDF (from Archive) - verify no unknown/invalid entries flagged
- [ ] T056 [US3] Validate against `specs/001-privacy-manifest/contracts/privacy-manifest-schema.md` - verify all 11 validation rules pass

**Checkpoint**: User Story 3 complete - Privacy compliance verified and documented for audit ✅

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and documentation across all user stories

- [ ] T057 [P] Run full test suite (cmd+U) - verify all PrivacyManifestTests pass (should be 20+ tests)
- [ ] T058 [P] Validate PrivacyInfo.xcprivacy with `plutil -lint` - verify syntax passes
- [ ] T059 [P] Clean build folder (cmd+shift+K) and rebuild - verify no warnings or errors
- [ ] T060 Archive and generate Privacy Report - verify consolidated report shows all declarations correctly
- [ ] T061 Upload to App Store Connect for final validation - verify upload succeeds with no ITMS errors
- [ ] T062 [P] Update `deployment-timeline.md` Critical Blocker #1 (Empty privacy manifest) - mark as COMPLETE
- [ ] T063 [P] Update `deployment-timeline.md` Critical Blocker #2 (Missing Info.plist permissions) - mark as COMPLETE
- [ ] T064 [P] Document completion in `specs/001-privacy-manifest/README.md` (if created) or update plan.md status to "Implemented"
- [ ] T065 Run quickstart.md validation steps 1-8 - verify all success criteria met

**Checkpoint**: All user stories complete, privacy manifest fully implemented and validated ✅

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately ✅
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories ✅
- **User Story 1 (Phase 3)**: Depends on Foundational (test framework ready)
- **User Story 2 (Phase 4)**: Can start after Foundational - independent of US1 (different file: Info.plist)
- **User Story 3 (Phase 5)**: Depends on US1 complete (validates US1 implementation correctness)
- **Polish (Phase 6)**: Depends on all user stories complete

### User Story Dependencies

- **User Story 1 (P1)**: INDEPENDENT after Foundational - edits PrivacyInfo.xcprivacy only
- **User Story 2 (P2)**: INDEPENDENT after Foundational - edits Info.plist only (different file)
- **User Story 3 (P3)**: DEPENDS on US1 - validates US1's privacy manifest declarations

### Within Each User Story (TDD Red-Green-Refactor)

1. **Red Phase**: Write tests FIRST, run tests (expect FAILURES)
2. **Green Phase**: Implement minimal code to make tests PASS
3. **Refactor Phase**: Clean up (minimal refactoring needed - XML editing only)
4. **Validate**: Run final validation steps

### Parallel Opportunities

**Phase 1 (Setup)**: All 3 tasks can run in parallel
- T001, T002, T003 - all read-only verification tasks

**Phase 2 (Foundational)**: Sequential (creating single test file)
- Must complete T004-T007 in order

**Phase 3 (User Story 1 - Tests)**: All test writing tasks can run in parallel
- T008, T009, T010, T011, T012, T013, T014, T015 - all writing different test methods

**Phase 4 (User Story 2 - Tests)**: All test writing tasks can run in parallel
- T028, T029, T030, T031 - all writing different test methods

**User Story 1 and 2 Implementation**: CAN run in PARALLEL after Foundational complete
- US1 edits `PrivacyInfo.xcprivacy`
- US2 edits `Info.plist`
- No file conflicts, independent implementations

**Phase 5 (User Story 3 - Tests)**: All test writing tasks can run in parallel
- T041, T042, T043, T044, T045, T046 - all writing different test methods

**Phase 6 (Polish)**: Parallelizable tasks
- T057, T058, T059, T062, T063, T064 - all independent validation/documentation

---

## Parallel Example: User Story 1 (Test-First)

```bash
# RED PHASE: Launch all test writing tasks together (PARALLEL):
Task T008: "Write testPrivacyManifestFileExists() in PrivacyManifestTests.swift"
Task T009: "Write testPrivacyManifestIsValidPlist() in PrivacyManifestTests.swift"
Task T010: "Write testNSPrivacyTrackingExists() in PrivacyManifestTests.swift"
Task T011: "Write testNSPrivacyCollectedDataTypesExists() in PrivacyManifestTests.swift"
Task T012: "Write testPhotoVideoDataCollectionDeclared() in PrivacyManifestTests.swift"
Task T013: "Write testNSPrivacyAccessedAPITypesExists() in PrivacyManifestTests.swift"
Task T014: "Write testUserDefaultsAPIDeclared() in PrivacyManifestTests.swift"
Task T015: "Write testFileTimestampAPIDeclared() in PrivacyManifestTests.swift"

# Run tests (cmd+U) - ALL SHOULD FAIL (this is correct!)

# GREEN PHASE: Implement sequentially in PrivacyInfo.xcprivacy:
Task T016-T023: Edit PrivacyInfo.xcprivacy with all declarations

# Run tests (cmd+U) - ALL SHOULD PASS
```

---

## Parallel Example: Cross-Story Parallelization

```bash
# After Foundational Phase complete, these can run in PARALLEL:

# Developer A (or LLM Session 1):
Implement User Story 1 (T008-T027): Edit PrivacyInfo.xcprivacy

# Developer B (or LLM Session 2):
Implement User Story 2 (T028-T040): Edit Info.plist

# Both complete independently, no merge conflicts
```

---

## Implementation Strategy

### MVP First (User Story 1 Only) - Recommended for Critical Blocker

1. ✅ Complete Phase 1: Setup (5 minutes)
2. ✅ Complete Phase 2: Foundational (15 minutes - create test file)
3. ✅ Complete Phase 3: User Story 1 (30 minutes - TDD Red-Green cycle)
   - Write 8 tests (T008-T015) → Run (FAIL) → Implement (T016-T023) → Run (PASS)
   - Validate (T024-T027)
4. **STOP and VALIDATE**: Upload to App Store Connect
5. ✅ **MVP COMPLETE** - Critical blocker resolved, app can be submitted

**Total MVP Time**: ~1 hour (matches plan.md estimate)

### Full Implementation (All User Stories)

1. Complete Setup + Foundational → Foundation ready
2. Complete User Story 1 (PrivacyInfo.xcprivacy) → Test independently → Upload to App Store ✅
3. Complete User Story 2 (Info.plist) → Test on device → Verify permission dialogs ✅
4. Complete User Story 3 (Compliance docs) → Audit ready ✅
5. Polish (Final validation) → Production ready ✅

**Total Time**: ~2 hours (matches plan.md estimate)

### Parallel Team Strategy (If Multiple Developers Available)

1. Team completes Setup + Foundational together (20 minutes)
2. Once Foundational done:
   - **Developer A**: User Story 1 (PrivacyInfo.xcprivacy) - 30 minutes
   - **Developer B**: User Story 2 (Info.plist) - 20 minutes
3. **Developer A** continues: User Story 3 (depends on US1 complete) - 30 minutes
4. Team validates together: Polish phase - 20 minutes

**Parallel Time Savings**: ~40 minutes saved (US1 and US2 in parallel)

---

## Test-First Development Workflow (Constitution Compliance)

Per Constitution Principle II (Test-First Development - MANDATORY):

### Red-Green-Refactor Cycle

**Phase 3 Example (User Story 1)**:

1. **RED**: Write failing tests
   - Execute T008-T015 (write 8 test methods)
   - Run `cmd+U` → 8 failures ✅ (expected)

2. **GREEN**: Make tests pass
   - Execute T016-T023 (edit PrivacyInfo.xcprivacy)
   - Run `cmd+U` → 8 passes ✅ (success!)

3. **REFACTOR**: Clean up (optional)
   - Minimal refactoring needed (XML editing only)
   - Verify tests still pass

4. **VALIDATE**: Final checks
   - Execute T024-T027 (plutil, build, archive, upload)

**Critical**: Tests MUST fail before implementation. If tests pass immediately, they are not testing the right thing!

---

## Notes

- **[P]** tasks = different files or different test methods, no dependencies, can run in parallel
- **[Story]** label maps task to specific user story for traceability
- **TDD Compliance**: All test tasks (T008-T015, T028-T031, T041-T046) MUST be written and FAIL before implementation tasks
- Each user story should be independently completable and testable (US1 and US2 have no interdependencies)
- Verify tests fail before implementing (Red phase validates tests are working)
- Commit after completing each user story phase
- Stop at any checkpoint to validate story independently
- **Critical Path**: Setup → Foundational → US1 → Upload to App Store Connect (resolves Critical Blocker #1)
- **Full Path**: Add US2 for better UX, add US3 for compliance documentation

---

## Success Criteria (From spec.md)

- **SC-001**: App submission to App Store Connect completes without privacy-related validation errors or warnings ✅ (User Story 1, Task T027)
- **SC-002**: Privacy manifest file passes Apple's automated validation checks with 100% compliance ✅ (User Story 1, Tasks T024-T027)
- **SC-003**: All camera and photo library permission requests display appropriate user-facing explanations when triggered ✅ (User Story 2, Tasks T037-T040)
- **SC-004**: Privacy review by compliance team confirms all API usage is properly declared with no undeclared privacy-sensitive API calls ✅ (User Story 3, Tasks T053-T056)

**All success criteria mapped to specific validation tasks** ✅

---

**Total Tasks**: 65
**Task Distribution**:
- Setup (Phase 1): 3 tasks
- Foundational (Phase 2): 4 tasks
- User Story 1 (Phase 3): 20 tasks (8 tests + 8 implementation + 4 validation)
- User Story 2 (Phase 4): 13 tasks (4 tests + 4 implementation + 5 validation)
- User Story 3 (Phase 5): 16 tasks (6 tests + 6 documentation + 4 validation)
- Polish (Phase 6): 9 tasks

**Parallel Opportunities**: 28 tasks marked [P] (43% parallelizable)

**MVP Scope**: Tasks T001-T027 (27 tasks, ~1 hour) - Resolves Critical Blocker #1 from deployment-timeline.md

**Format Validation**: ✅ All 65 tasks follow checklist format with checkbox, ID, labels, and file paths
