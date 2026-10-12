import DigUpLocalization

nonisolated func L(_ key: String, _ arguments: CVarArg...) -> String {
    DigUpLocalization.string(key, arguments: arguments)
}
