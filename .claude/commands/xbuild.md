---
name: xbuild
description: Build and test the GrindLab Xcode project with intelligent error handling
permissions:
  bash: true
---

# Xcode Build and Test Command

Build and/or test the GrindLab iOS app with comprehensive error analysis.

## Context

- **Project**: Coffee Grind Analyzer.xcodeproj
- **Scheme**: Coffee Grind Analyzer
- **Target**: iOS app for coffee grind analysis using computer vision
- **Test Framework**: Swift Testing (Xcode)

## Tasks

1. **Determine the action** based on user input:
   - If user says "build": Build only
   - If user says "test": Run tests only
   - If user says "clean": Clean build folder
   - If no specific action: Build and test

2. **Execute the appropriate xcodebuild command**:
   ```bash
   # Build
   xcodebuild -project "Coffee Grind Analyzer.xcodeproj" \
     -scheme "Coffee Grind Analyzer" \
     -destination "platform=iOS Simulator,name=iPhone 15" \
     build

   # Test
   xcodebuild test -project "Coffee Grind Analyzer.xcodeproj" \
     -scheme "Coffee Grind Analyzer" \
     -destination "platform=iOS Simulator,name=iPhone 15"

   # Clean
   xcodebuild clean -project "Coffee Grind Analyzer.xcodeproj" \
     -scheme "Coffee Grind Analyzer"
   ```

3. **Analyze build output**:
   - Parse compilation errors (Swift syntax, type errors, etc.)
   - Identify failed tests with specific failure reasons
   - Extract warnings and suggestions
   - Look for common iOS build issues (missing frameworks, signing, etc.)

4. **Provide actionable fixes**:
   - For compilation errors: Show exact file:line and suggest fixes
   - For test failures: Show failed test names and assertions
   - For warnings: Explain impact and suggest improvements
   - For signing issues: Guide through resolution

5. **Offer next steps**:
   - If build succeeds: Suggest running tests or opening in Xcode
   - If tests fail: Offer to fix specific test failures
   - If errors found: Ask if you should fix them

## Error Patterns to Watch For

- **Swift Compiler Errors**: Syntax, type mismatches, undefined symbols
- **SwiftUI Issues**: Invalid view hierarchies, state management
- **Vision Framework**: Missing imports, API misuse
- **Test Failures**: Assertion failures, timeout issues
- **Simulator Issues**: Simulator not booted, connection errors
- **Code Signing**: Provisioning profile or entitlements issues

## Output Format

Provide a clear summary:
- ✅ **Build Status**: Success/Failure
- 📊 **Statistics**: Build time, warnings count, tests run
- ❌ **Errors**: List with file:line references
- ⚠️  **Warnings**: Important warnings only
- 🔧 **Suggested Fixes**: Concrete next steps
