#!/usr/bin/swift
import Foundation

// Count "usable" lines of Swift code (non-tests):
// - Includes only .swift files in the project
// - Excludes files in any *Tests* directory and files ending with "Tests.swift"
// - Excludes common build/dependency directories (.git, DerivedData, build, .build, Pods, Carthage, .swiftpm, Package.swift of deps)
// - Counts only non-empty, non-comment lines (strips // line comments and /* ... */ block comments)
// - Handles multiline strings (""") so comment markers inside strings aren't mistaken for comments
//
// Usage:
//   swift CountUsableLOC.swift [path]
// or
//   chmod +x CountUsableLOC.swift && ./CountUsableLOC.swift [path]

struct FileLOC {
    let url: URL
    let loc: Int
}

let fm = FileManager.default
let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
let root: URL = {
    if CommandLine.arguments.count > 1 {
        return URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
    } else {
        return cwd
    }
}()

let excludedDirNames: Set<String> = [
    ".git", "DerivedData", "build", ".build", "Pods", "Carthage", ".swiftpm"
]

func isExcludedDirectory(_ url: URL) -> Bool {
    let parts = url.pathComponents
    for p in parts {
        if excludedDirNames.contains(p) { return true }
        // Exclude any directory whose name ends with "Tests"
        if p.hasSuffix("Tests") { return true }
    }
    return false
}

func isTestFile(_ url: URL) -> Bool {
    let file = url.lastPathComponent
    if file.hasSuffix("Tests.swift") { return true }
    // Also exclude any file that resides in a directory named *Tests*
    return url.pathComponents.contains { $0.hasSuffix("Tests") }
}

func swiftFiles(at root: URL) -> [URL] {
    var results: [URL] = []
    let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])

    while let item = enumerator?.nextObject() as? URL {
        // Skip excluded directories quickly
        if let values = try? item.resourceValues(forKeys: [.isDirectoryKey]), values.isDirectory == true {
            if isExcludedDirectory(item) {
                enumerator?.skipDescendants()
                continue
            }
        }

        if item.pathExtension == "swift" {
            if isExcludedDirectory(item) { continue }
            if isTestFile(item) { continue }
            results.append(item)
        }
    }
    return results
}

// A small parser to strip comments while respecting strings (including multiline """ strings)
func countUsableLines(in fileURL: URL) -> Int {
    guard let data = try? Data(contentsOf: fileURL), let text = String(data: data, encoding: .utf8) else {
        return 0
    }

    var total = 0

    var inBlockComment = false
    var inString = false // standard double-quoted string
    var inMultilineString = false // """ ... """
    var stringDelimiterCount = 0 // track consecutive quotes to detect """

    // Process line-by-line but keep block comment state across lines
    let lines = text.split(omittingEmptySubsequences: false, whereSeparator: { $0 == "\n" || $0 == "\r\n" || $0 == "\r" })

    for rawLine in lines {
        let line = String(rawLine)
        var i = line.startIndex
        var output = ""
        var inLineComment = false
        var prevChar: Character? = nil
        var escape = false // for string escapes

        // Reset per-line stringDelimiterCount only when not in a string
        stringDelimiterCount = 0

        while i < line.endIndex {
            let ch = line[i]
            let nextIndex = line.index(after: i)
            let nextChar: Character? = nextIndex < line.endIndex ? line[nextIndex] : nil

            // Handle line comment start if not in any string/block comment
            if !inString && !inMultilineString && !inBlockComment && !inLineComment {
                if ch == "/" && nextChar == "/" {
                    // // line comment begins -> ignore rest of line
                    inLineComment = true
                    break
                }
                if ch == "/" && nextChar == "*" {
                    // /* block comment start */
                    inBlockComment = true
                    // skip both characters
                    i = line.index(after: nextIndex)
                    prevChar = nil
                    continue
                }
            }

            if inBlockComment {
                // look for end of block comment */
                if ch == "*" && nextChar == "/" {
                    inBlockComment = false
                    i = line.index(after: nextIndex)
                    prevChar = nil
                    continue
                } else {
                    i = nextIndex
                    prevChar = ch
                    continue
                }
            }

            // Handle strings
            if inMultilineString {
                // Detect end of """
                if ch == "\"" {
                    stringDelimiterCount += 1
                } else {
                    stringDelimiterCount = 0
                }
                if stringDelimiterCount >= 3 {
                    // End of multiline string
                    inMultilineString = false
                    stringDelimiterCount = 0
                }
                // Within strings, we keep characters as code (they are code, not comments)
                output.append(ch)
                i = nextIndex
                prevChar = ch
                continue
            }

            if inString {
                if !escape && ch == "\\" { // start escape
                    escape = true
                    output.append(ch)
                    i = nextIndex
                    prevChar = ch
                    continue
                }
                if escape {
                    // escaped character inside string
                    escape = false
                    output.append(ch)
                    i = nextIndex
                    prevChar = ch
                    continue
                }
                // end of normal string
                if ch == "\"" {
                    inString = false
                }
                output.append(ch)
                i = nextIndex
                prevChar = ch
                continue
            }

            // Not in string/comment: detect start of strings
            if ch == "\"" {
                // Check for """ (multiline)
                if nextChar == "\"" {
                    let thirdIndex = nextIndex < line.endIndex ? line.index(after: nextIndex) : nextIndex
                    let thirdChar: Character? = thirdIndex < line.endIndex ? line[thirdIndex] : nil
                    if thirdChar == "\"" {
                        inMultilineString = true
                        stringDelimiterCount = 3
                        // Append quotes as part of code
                        output.append(ch)
                        output.append(line[nextIndex])
                        output.append(line[thirdIndex])
                        i = line.index(after: thirdIndex)
                        prevChar = "\""
                        continue
                    }
                }
                // Start normal string
                inString = true
                output.append(ch)
                i = nextIndex
                prevChar = ch
                continue
            }

            // Normal code character
            output.append(ch)
            i = nextIndex
            prevChar = ch
        }

        // After processing the line, if we are not in a comment, count non-empty output
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !inBlockComment {
            total += 1
        }
    }

    return total
}

let files = swiftFiles(at: root)
if files.isEmpty {
    print("No Swift files found at: \(root.path)")
    exit(0)
}

var fileLOCs: [FileLOC] = []
var totalLOC = 0

for url in files {
    let loc = countUsableLines(in: url)
    totalLOC += loc
    fileLOCs.append(FileLOC(url: url, loc: loc))
}

fileLOCs.sort { $0.loc > $1.loc }

print("\n==============================")
print("Usable Swift LOC (non-tests)")
print("Root: \(root.path)")
print("Included files: \(fileLOCs.count)")
print("Total usable LOC: \(totalLOC)")
print("==============================\n")

// Show top 20 largest files for insight
let topN = min(20, fileLOCs.count)
if topN > 0 {
    print("Top \(topN) files by LOC:")
    for entry in fileLOCs.prefix(topN) {
        let relPath = entry.url.path.replacingOccurrences(of: root.path + "/", with: "")
        print(String(format: "%6d  %@", entry.loc, relPath))
    }
}

print("\nTOTAL USABLE LOC: \(totalLOC)\n")

// Exit code 0 with success
exit(0)
