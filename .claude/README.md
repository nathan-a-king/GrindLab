# GrindLab Claude Code Setup

Custom Claude Code capabilities for the GrindLab iOS coffee grind analysis app.

## What's Installed

### 📋 Slash Commands

#### `/xbuild [action]`
Build and test the Xcode project with intelligent error handling.

**Usage:**
```bash
/xbuild              # Build and test
/xbuild build        # Build only
/xbuild test         # Run tests only
/xbuild clean        # Clean build folder
```

**Features:**
- Parses compilation errors with file:line references
- Identifies failed tests with detailed assertions
- Provides actionable fix suggestions
- Optimized for GrindLab's architecture

**Location:** `.claude/commands/xbuild.md`

---

#### `/test-ios [options]`
Run iOS tests with filtering, coverage, and detailed failure analysis.

**Usage:**
```bash
/test-ios                    # Run all tests
/test-ios unit               # Run only unit tests
/test-ios ui                 # Run only UI tests
/test-ios AnalysisEngine     # Run tests matching "AnalysisEngine"
/test-ios --coverage         # Enable code coverage report
/test-ios --verbose          # Show full test output
```

**Features:**
- Specific test class targeting
- Test type filtering (unit/UI)
- Code coverage analysis
- Detailed failure diagnostics
- Performance test results

**Location:** `.claude/commands/test-ios.md`

---

### 🛠️ Skills

#### Swift Testing Skill
Automatically generates comprehensive unit tests for Swift code.

**Activates when:**
- You ask to "write tests", "add tests", "generate tests"
- You mention "test coverage", "unit tests", "XCTest"
- You ask to test specific Swift files or classes

**Capabilities:**
- Generate XCTest classes with proper structure
- Create test cases for happy path, edge cases, and errors
- Mock Vision framework, camera operations, Core Image
- Generate test fixtures and sample data
- Provide coverage analysis and recommendations

**GrindLab Focus Areas:**
- `CoffeeAnalysisEngine` - Core analysis logic
- `ParticleSeparationEngine` - Particle detection
- `AdvancedStatistics` - Statistical calculations
- `CoffeeAnalysisHistory` - Persistence
- `TimerVM` - Timer accuracy
- `CoffeeModels` - Data encoding/decoding

**Files:**
- `.claude/skills/swift-testing/SKILL.md`
- `.claude/skills/swift-testing/test_helpers.py`

**Example:**
```
You: "Add tests for CoffeeAnalysisEngine"
Claude: [Reads CoffeeAnalysisEngine.swift, generates comprehensive test suite]
```

---

### 🤖 Agents

#### iOS Vision Expert Agent
Specialist in SwiftUI, Vision framework, AVFoundation, and iOS image processing.

**Expertise:**
- Vision Framework: Image analysis, object detection, feature extraction
- SwiftUI: MVVM, state management, navigation, custom views
- Camera & Image Processing: AVFoundation, Core Image, real-time processing
- Mathematical Analysis: Statistics, histograms, calibration math
- GrindLab Architecture: Deep understanding of the coffee analysis pipeline

**When to Use:**
- Computer vision algorithm improvements
- Camera capture issues
- Image analysis optimization
- SwiftUI architecture questions
- Performance profiling guidance
- Vision framework usage
- Statistical analysis validation

**Automatically Engages:**
- When you discuss Vision framework, camera, or image processing
- When working on analysis algorithms
- When debugging SwiftUI views
- When optimizing performance

**File:** `.claude/agents/ios-vision-expert.md`

---

### 🪝 Hooks (Automation)

#### Pre-Commit Build Check
Automatically runs before git commits to ensure code compiles.

**What it does:**
1. ✅ Checks for staged files (blocks if none)
2. 🔨 Runs `xcodebuild` to verify project builds
3. ❌ Blocks commit if build fails
4. ✅ Allows commit if build succeeds

**Triggers:** Any `git commit` command

**Timeout:** 120 seconds (build time)

---

#### Main Branch Push Warning
Warns when pushing directly to main branch.

**What it does:**
⚠️  Displays warning about direct main branch pushes

**Triggers:** `git push origin main` or similar

**Does not block** - just provides a friendly reminder

---

**Configuration:** `.claude/settings.local.json` (hooks section)

**Note:** Restart Claude Code to activate hooks after changes

---

## Quick Start

### 1. Build the Project
```
/xbuild
```

### 2. Run All Tests
```
/test-ios
```

### 3. Generate Tests for a Class
```
Add unit tests for CoffeeAnalysisEngine
```
(The Swift testing skill will activate automatically)

### 4. Get Expert Help
```
How can I improve particle detection accuracy in low-light images?
```
(The iOS vision expert agent will engage)

### 5. Make a Commit
Just run `git commit` as normal - the pre-commit hook will:
- Verify you have staged changes
- Build the project automatically
- Block commit if build fails

---

## Project Context

**GrindLab** is an iOS app that analyzes coffee grind consistency using computer vision.

### Tech Stack
- **Language:** Swift
- **UI:** SwiftUI
- **Vision:** Apple Vision Framework
- **Camera:** AVFoundation
- **Image Processing:** Core Image
- **Platform:** iOS 16+

### Key Components
- **Analysis Engine** (`CoffeeAnalysisEngine.swift`) - Main orchestration
- **Particle Detection** (`ParticleSeparationEngine.swift`) - Computer vision
- **Statistics** (`AdvancedStatistics.swift`) - Mathematical analysis
- **Camera** (`CoffeeCamera.swift`) - AVFoundation integration
- **Views** (`ResultsView.swift`, etc.) - SwiftUI interface
- **Models** (`CoffeeModels.swift`) - Data structures

### Grind Types
- Espresso: 170-300μm
- Filter/Pour-Over: 400-800μm
- French Press: 750-1000μm
- Cold Brew: 800-1200μm
- Turkish: 50-150μm

---

## Testing Strategy

### Current State
- Minimal test coverage (stub tests only)
- Significant opportunity for expansion

### Priority Test Areas
1. **CoffeeAnalysisEngine** - Core analysis logic (high priority)
2. **ParticleSeparationEngine** - Particle detection algorithms
3. **AdvancedStatistics** - Mathematical calculations
4. **CoffeeAnalysisHistory** - Data persistence
5. **TimerVM** - Timer accuracy and state
6. **CoffeeModels** - Encoding/decoding

### Test Approaches
- **Unit Tests:** Analysis algorithms, statistics, models
- **UI Tests:** Critical user flows, view rendering
- **Mock Data:** Camera images, Vision responses, sample results
- **Edge Cases:** Nil inputs, empty data, invalid images

Use `/test-ios` to run tests and the Swift testing skill to generate new ones.

---

## Tips & Best Practices

### Building
- Use `/xbuild` for quick builds with error analysis
- Pre-commit hook ensures main branch stays buildable
- Build errors include file:line references for easy navigation

### Testing
- Start with `/test-ios` to see current test status
- Generate tests incrementally (one class at a time)
- Focus on high-value areas first (analysis engine, statistics)
- Mock expensive operations (camera, Vision framework)

### Development Workflow
1. Make code changes
2. Run `/xbuild` to verify compilation
3. Run `/test-ios` to verify tests pass
4. Generate tests if needed: "Add tests for [ClassName]"
5. Commit (pre-commit hook runs automatically)

### Getting Help
- Ask specific questions about SwiftUI, Vision, or camera issues
- The iOS vision expert agent will engage automatically
- Reference file names and line numbers for precise help
- Use "How do I..." or "Why is..." to trigger detailed explanations

---

## Customization

### Add More Slash Commands
Create new `.md` files in `.claude/commands/`:
```markdown
---
name: my-command
description: What it does
permissions:
  bash: true
---

Command instructions here...
```

### Add More Hooks
Edit `.claude/settings.local.json`:
```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash:pattern*",
        "hooks": [
          {
            "type": "command",
            "command": "your-command-here",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

### Modify Existing Capabilities
All files in `.claude/` can be edited:
- Commands: `.claude/commands/*.md`
- Skills: `.claude/skills/*/SKILL.md`
- Agents: `.claude/agents/*.md`
- Hooks: `.claude/settings.local.json`

Changes take effect immediately (except hooks - restart Claude Code).

---

## Troubleshooting

### Hooks Not Running
1. Check `.claude/settings.local.json` syntax (must be valid JSON)
2. Restart Claude Code after changing hooks
3. Verify matcher patterns match your commands

### Build Command Fails
1. Open project in Xcode: `open "Coffee Grind Analyzer.xcodeproj"`
2. Check for scheme/destination issues
3. Verify simulator "iPhone 15" is available
4. Try building in Xcode first to identify issues

### Tests Not Running
1. Check that test targets are included in scheme
2. Verify simulator is available and bootable
3. Run `/test-ios --verbose` for detailed output
4. Try running tests directly in Xcode

### Skills Not Activating
1. Check that `.claude/skills/` directory exists
2. Verify `SKILL.md` has correct format
3. Use explicit phrases like "write tests" or "add tests"
4. Skills activate based on context - be specific

### Agents Not Engaging
1. Agents activate automatically based on their description
2. For manual invocation, mention their domain (Vision framework, SwiftUI)
3. Check `.claude/agents/*.md` files are present
4. Be specific about iOS/Swift development topics

---

## File Structure

```
/Users/nate/Developer/GrindLab/.claude/
├── README.md                           # This file
├── settings.local.json                 # Hooks and permissions
├── commands/
│   ├── xbuild.md                       # Build/test command
│   └── test-ios.md                     # Test runner command
├── skills/
│   └── swift-testing/
│       ├── SKILL.md                    # Testing skill instructions
│       └── test_helpers.py             # Test generation utilities
└── agents/
    └── ios-vision-expert.md            # iOS specialist agent
```

---

## Learn More

- **Claude Code Docs:** https://docs.claude.com/en/docs/claude-code
- **Skills Guide:** https://docs.claude.com/en/docs/agents-and-tools/agent-skills
- **Vision Framework:** https://developer.apple.com/documentation/vision
- **SwiftUI:** https://developer.apple.com/documentation/swiftui
- **XCTest:** https://developer.apple.com/documentation/xctest

---

**Version:** 1.0
**Created:** 2025-11-01
**For:** GrindLab iOS App
**Repository:** https://github.com/nathan-a-king/GrindLab
