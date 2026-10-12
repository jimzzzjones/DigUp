import Foundation

public enum DigUpLocalization {
    static var availableLocalizations: [String] { Bundle.module.localizations }

    public static func string(_ key: String, arguments: [CVarArg] = []) -> String {
        format(Bundle.module.localizedString(forKey: key, value: key, table: nil), locale: .current,
               arguments: arguments)
    }

    static func string(_ key: String, language: String, arguments: [CVarArg] = []) -> String {
        guard let path = Bundle.module.path(forResource: language, ofType: "lproj"), let bundle = Bundle(path: path) else {
            return format(key, locale: Locale(identifier: "en"), arguments: arguments)
        }
        return format(bundle.localizedString(forKey: key, value: key, table: nil), locale: Locale(identifier: language),
                      arguments: arguments)
    }

    static func table(named name: String = "Localizable", language: String) throws -> [String: String] {
        guard let url = Bundle.module.url(forResource: name, withExtension: "strings",
                                          subdirectory: nil, localization: language) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try Data(contentsOf: url)
        guard let table = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return table
    }

    private static func format(_ value: String, locale: Locale, arguments: [CVarArg]) -> String {
        guard !arguments.isEmpty else { return value }
        return String(format: value, locale: locale, arguments: arguments)
    }
}
