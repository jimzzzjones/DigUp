import Foundation
import Testing
@testable import DigUpLocalization

@Test func bundledLanguagesAndFallback() throws {
    let languages = Set(DigUpLocalization.availableLocalizations.map { $0.lowercased() })
    #expect(languages.contains("en"))
    #expect(languages.contains("zh-hans"))
    #expect(DigUpLocalization.string("About DigUp", language: "en") == "About DigUp")
    #expect(DigUpLocalization.string("About DigUp", language: "zh-Hans") == "关于 DigUp")
    #expect(DigUpLocalization.string("About DigUp", language: "fr") == "About DigUp")
}

@Test func simplifiedChineseTablePreservesFormatArguments() throws {
    let english = try DigUpLocalization.table(language: "en")
    let table = try DigUpLocalization.table(language: "zh-Hans")
    #expect(table.count >= 250)
    #expect(Set(english.keys) == Set(table.keys))
    for (key, value) in table {
        #expect(!value.isEmpty, "Empty translation for \(key)")
        #expect(formatArguments(in: key) == formatArguments(in: value), "Format mismatch for \(key)")
    }

    let reordered = DigUpLocalization.string(
        "DigUp starts reading your folders%@ once the model has downloaded (%@). Until then, search finds files by name.",
        language: "zh-Hans", arguments: ["（约 2 分钟）", "42%"])
    #expect(reordered.contains("42%"))
    #expect(reordered.contains("约 2 分钟"))
    #expect(DigUpLocalization.string("Indexing %@%%", language: "zh-Hans", arguments: ["42"]) == "正在编制索引 42%")
}

@Test func permissionDescriptionsAreLocalized() throws {
    let english = try DigUpLocalization.table(named: "InfoPlist", language: "en")
    let chinese = try DigUpLocalization.table(named: "InfoPlist", language: "zh-Hans")
    let keys = ["NSAppleEventsUsageDescription", "NSDesktopFolderUsageDescription",
                "NSDocumentsFolderUsageDescription", "NSDownloadsFolderUsageDescription",
                "NSRemovableVolumesUsageDescription"]
    for key in keys {
        #expect(english[key]?.isEmpty == false)
        #expect(chinese[key]?.isEmpty == false)
        #expect(english[key] != chinese[key])
    }
}

@Test func literalLookupKeysExistInBothLanguages() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    let sourceFolder = root.appendingPathComponent("Sources/DigUpApp")
    let files = try FileManager.default.contentsOfDirectory(at: sourceFolder, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "swift" }
    let call = try NSRegularExpression(pattern: #"L\(((?:\"(?:\\.|[^\"\\])*\"\s*\+\s*)*\"(?:\\.|[^\"\\])*\")(?=\s*[,\)])"#)
    let literal = try NSRegularExpression(pattern: #"\"((?:\\.|[^\"\\])*)\""#)
    let localizedInitializers = try NSRegularExpression(
        pattern: #"(?:Text|Button|Label|Section|Picker|LabeledContent|TextField|Toggle)\(\"((?:\\.|[^\"\\])*)\""#)
    let localizedModifiers = try NSRegularExpression(
        pattern: #"\.(?:help|accessibilityLabel|accessibilityHint|confirmationDialog|navigationTitle)\(\"((?:\\.|[^\"\\])*)\""#)
    var keys = Set<String>()
    for file in files {
        let source = try String(contentsOf: file, encoding: .utf8)
        for match in call.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
            let expressionRange = Range(match.range(at: 1), in: source)!
            let expression = String(source[expressionRange])
            let pieces = literal.matches(in: expression, range: NSRange(expression.startIndex..., in: expression)).map {
                String(expression[Range($0.range(at: 1), in: expression)!])
            }
            let key = try pieces.map(decodeSwiftString).joined()
            keys.insert(key)
        }
        for regex in [localizedInitializers, localizedModifiers] {
            for match in regex.matches(in: source, range: NSRange(source.startIndex..., in: source)) {
                let raw = String(source[Range(match.range(at: 1), in: source)!])
                if !raw.contains(#"\("#) {
                    keys.insert(try decodeSwiftString(raw))
                }
            }
        }
    }
    let english = try DigUpLocalization.table(language: "en")
    let chinese = try DigUpLocalization.table(language: "zh-Hans")
    #expect(keys.subtracting(english.keys).isEmpty)
    #expect(keys.subtracting(chinese.keys).isEmpty)
}

private func formatArguments(in value: String) -> [String] {
    let pattern = #"%(?:([0-9]+)\$)?(lld|ld|@|d|i|u|f)"#
    let regex = try! NSRegularExpression(pattern: pattern)
    let range = NSRange(value.startIndex..., in: value)
    return regex.matches(in: value, range: range).map { match in
        let typeRange = Range(match.range(at: 2), in: value)!
        return String(value[typeRange])
    }.sorted()
}

private func decodeSwiftString(_ value: String) throws -> String {
    try JSONDecoder().decode(String.self, from: Data("\"\(value)\"".utf8))
}
