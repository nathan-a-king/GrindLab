<!--
SYNC IMPACT REPORT
==================
Version Change: Initial → 1.0.0
Rationale: First constitution establishing core architectural principles for GrindLab iOS/macOS computer vision app

Modified Principles: N/A (initial version)
Added Sections:
  - I. SwiftUI-First Architecture
  - II. Test-First Development (MANDATORY)
  - III. Performance & Accuracy
  - IV. Simplicity & Focus
  - Governance

Removed Sections: N/A (initial version)

Templates Requiring Updates:
  ✅ plan-template.md - Constitution Check section already includes placeholder for gates
  ✅ spec-template.md - User scenarios and acceptance criteria align with testability requirement
  ✅ tasks-template.md - Test-first workflow already structured (tests before implementation)
  ⚠ checklist-template.md - Not reviewed (no constitution-specific checks needed)
  ⚠ agent-file-template.md - Not reviewed (agent-specific, not constitution-dependent)

Follow-up TODOs: None - all placeholders filled
-->

# GrindLab Constitution

## Core Principles

### I. SwiftUI-First Architecture

**Rule**: All UI components MUST be built using SwiftUI following Apple's declarative paradigm. Views are stateless presentations; business logic resides in ViewModels or service layers.

**Requirements**:
- Views observe state via `@State`, `@Binding`, `@ObservedObject`, or `@EnvironmentObject`
- Camera and Vision framework integrations use UIViewControllerRepresentable/UIViewRepresentable bridges
- Reusable components follow single-responsibility principle
- Navigation uses SwiftUI native patterns (NavigationStack, TabView, sheets)

**Rationale**: SwiftUI provides maintainable, testable, and platform-consistent UI code. Separating state management from presentation enables easier testing and reduces complexity.

---

### II. Test-First Development (MANDATORY)

**Rule**: All new features and bug fixes MUST follow strict TDD (Test-Driven Development). Tests are written BEFORE implementation and MUST fail initially.

**Requirements**:
- Red-Green-Refactor cycle: Write failing test → Make it pass → Refactor
- Unit tests for business logic (analysis algorithms, data models, persistence)
- Integration tests for camera/Vision pipeline workflows
- UI tests for critical user journeys (capture → analyze → save results)
- Tests run in CI before merge

**Rationale**: Computer vision and image processing are error-prone domains. TDD ensures correctness, catches regressions early, and provides living documentation of expected behavior. Non-negotiable for maintaining accuracy and reliability.

---

### III. Performance & Accuracy

**Rule**: Vision framework processing and camera operations MUST meet real-time performance standards while maintaining analysis accuracy.

**Requirements**:
- Particle detection completes within 3 seconds for typical grind images
- Camera preview runs at minimum 30 fps on target devices (iOS 26+)
- Analysis accuracy validated against known reference samples (coin calibration tests)
- Memory usage stays under 150MB during image processing
- Performance regressions caught in integration tests

**Rationale**: Users expect immediate feedback when analyzing coffee grounds. Slow processing breaks the experience. Accuracy is paramount—incorrect grind size recommendations lead to poor coffee quality and erode trust in the app.

---

### IV. Simplicity & Focus

**Rule**: Implement only what is needed for current requirements. Avoid abstractions, patterns, or features not directly solving user problems.

**Requirements**:
- No premature optimization or speculative features
- Prefer standard library and native frameworks over third-party dependencies
- Single-purpose models and services (e.g., CoffeeAnalysisEngine does analysis, not persistence)
- YAGNI: "You Aren't Gonna Need It" applies to all architectural decisions
- Justify any complexity that violates simplicity in plan.md Complexity Tracking table

**Rationale**: Over-engineering increases maintenance burden, cognitive load, and bug surface area. Coffee grind analysis is complex enough at the domain level—keep the code simple to stay focused on delivering value.

---

## Additional Constraints

### Platform & Compatibility

- Target: iOS 26.0+, macOS compatible where applicable
- Xcode 26.0+ required for builds
- Swift 5.9+ language features allowed
- Vision framework, AVFoundation, Core Image, SwiftUI as core dependencies
- No third-party analytics, tracking, or cloud dependencies without explicit approval

### Data & Privacy

- All analysis data stored locally (UserDefaults for settings, JSON files for history)
- No network calls or cloud storage—fully offline capable
- Camera permissions clearly explained in Info.plist descriptions
- User data deletion via standard iOS settings

---

## Development Workflow

### Feature Development

1. Specification created in `.specify/specs/[###-feature-name]/spec.md` using `/speckit.specify`
2. Implementation plan designed in `plan.md` using `/speckit.plan` (includes Constitution Check gate)
3. Tasks generated in `tasks.md` using `/speckit.tasks` (tests listed first per Principle II)
4. Implementation follows task order: tests (fail) → implementation → tests (pass)
5. Code review verifies compliance before merge

### Constitution Compliance

- **Constitution Check Gate**: Every plan.md MUST include a Constitution Check section validating adherence to principles I-IV
- Non-compliance requires justification in Complexity Tracking table
- Unjustified violations block implementation approval

### Quality Gates

- All tests pass (unit + integration + UI where applicable)
- No performance regressions (measured via XCTest metrics)
- Code formatted with swift-format (if installed) or follows project conventions
- SwiftLint warnings addressed (if installed)

---

## Governance

### Amendment Process

1. Propose changes via GitHub issue tagged `constitution-amendment`
2. Document rationale and impact on existing features
3. Approval required from project maintainers
4. Update constitution version following semantic versioning:
   - **MAJOR**: Principle removal or backward-incompatible governance changes
   - **MINOR**: New principle added or major expansion of existing principle
   - **PATCH**: Clarifications, wording improvements, typo fixes
5. Sync changes across all `.specify/templates/*.md` files
6. Commit with message: `docs: amend constitution to vX.Y.Z (description)`

### Versioning Policy

This constitution follows semantic versioning (MAJOR.MINOR.PATCH). Version increments signal:
- **Breaking changes** (MAJOR): Existing plans may no longer comply
- **Additive changes** (MINOR): New requirements added
- **Clarifications** (PATCH): No new requirements, just clearer language

### Compliance Review

- Conducted during plan approval (Constitution Check gate)
- Quarterly audit of recent features for adherence
- Non-compliant code requires refactoring or retrospective justification

---

**Version**: 1.0.0 | **Ratified**: 2026-01-11 | **Last Amended**: 2026-01-11
