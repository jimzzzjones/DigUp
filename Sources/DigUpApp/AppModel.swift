import AppKit
import Observation

/// State the menubar, the panel and the windows share. Engine updates arrive on the main thread.
@Observable
final class AppModel {
    var status = EngineStatus()
    var settings: AppSettings
    var hotkey: KeyCombo?
    let download: ModelDownload
    /// A newer DigUp the daily check found ("0.6.1"), until you open it (`Updates`).
    var updateAvailable: String?

    init(settings: AppSettings, download: ModelDownload) {
        self.settings = settings
        self.download = download
    }

    var hasFolders: Bool { !settings.roots.isEmpty }
    /// Code search is on (there are code folders).
    var hasCode: Bool { !settings.codeRoots.isEmpty }

    /// One line for the menu and the windows: what the index is doing.
    var statusLine: String {
        let status = self.status
        guard hasFolders else { return L("No folders chosen yet") }
        switch status.activity {
        case .starting: return L("Starting…")
        case .failed(let problem): return L("⚠︎ %@", problem)
        case .syncing: return L("Checking folders…")
        case .indexing(let done, let total):
            let percent = total > 0 ? Int((Double(done) / Double(total) * 100).rounded(.down)) : 0
            return L("Indexing %@%% · %@ of %@", String(percent), done.formatted(), total.formatted())
        case .finishing(let done, let total, let files):
            let percent = total > 0 ? Int((Double(done) / Double(total) * 100).rounded(.down)) : 0
            let which = files > 0
                ? (files == 1 ? L("%@ long file", files.formatted()) : L("%@ long files", files.formatted()))
                : L("long files")
            return L("Reading the rest of %@ · %@%%", which, String(percent))
        case .idle:
            if let line = downloadLine { return line }
            if let code = status.code.indexing, code.total > 0 {
                let percent = Int((Double(code.done) / Double(code.total) * 100).rounded(.down))
                return L("Indexing code %@%% · %@ of %@", String(percent), code.done.formatted(),
                         code.total.formatted())
            }
            let waiting = status.pending == 1 ? L("%@ file waiting", status.pending.formatted())
                : L("%@ files waiting", status.pending.formatted())
            if status.pending > 0, status.paused { return L("Paused · %@", waiting) }
            if status.pending > 0, let reason = status.waitingFor { return L("%@ · %@", waiting, reason) }
            if status.pending > 0 { return L("%@ to be indexed", waiting) }
            if status.unfinished > 0 {
                let rest = status.unfinished == 1 ? L("%@ long file to finish", status.unfinished.formatted())
                    : L("%@ long files to finish", status.unfinished.formatted())
                if status.paused { return L("Paused · %@", rest) }
                if let reason = status.waitingFor { return L("%@ · %@", rest, reason) }
            }
            let indexed = status.searchable == 1 ? L("%@ file indexed", status.searchable.formatted())
                : L("%@ files indexed", status.searchable.formatted())
            return indexed + (status.paused ? L(" · paused") : "")
        }
    }

    /// While the model isn't there, how its download goes.
    private var downloadLine: String? {
        switch download.phase {
        case .ready: nil
        case .downloading: L("Downloading the model · %@%%", String(Int(download.fraction * 100)))
        case .verifying: L("Checking the model download…")
        case .retrying: L("Model download: waiting for the network")
        case .failed: L("⚠︎ The model download stopped")
        case .needed: status.pending > 0 ? L("The model isn't downloaded yet") : nil
        }
    }

    /// 0…1 for the menubar ring and progress bars: the model download, then an indexing pass or the rest of long files.
    var progress: Double? {
        if download.isActive { return download.fraction }
        switch status.activity {
        case .indexing(let done, let total) where total > 0: return Double(done) / Double(total)
        case .finishing(let done, let total, _) where total > 0: return Double(done) / Double(total)
        case .idle:
            guard let code = status.code.indexing, code.total > 0 else { return nil }
            return Double(code.done) / Double(code.total)
        default: return nil
        }
    }

    /// One line about the code index, for Settings → Code: "812 code files indexed", "Indexing code 42%…".
    var codeStatusLine: String {
        let code = status.code
        guard hasCode else { return L("Code search is off") }
        if !download.isReady { return L("Code is read once the model has downloaded") }
        if let indexing = code.indexing, indexing.total > 0 {
            let percent = Int((Double(indexing.done) / Double(indexing.total) * 100).rounded(.down))
            return L("Indexing code %@%% · %@ of %@", String(percent), indexing.done.formatted(),
                     indexing.total.formatted())
        }
        let waiting = code.pending > 0 ? L(" · %@ waiting", code.pending.formatted()) : ""
        if code.pending > 0, status.paused { return L("Paused · %@ code files waiting", code.pending.formatted()) }
        if code.pending > 0, let reason = status.waitingFor {
            return L("%@ code files waiting · %@", code.pending.formatted(), reason)
        }
        let indexed = code.searchable == 1 ? L("%@ code file indexed", code.searchable.formatted())
            : L("%@ code files indexed", code.searchable.formatted())
        return indexed + waiting
    }

    /// A few words for the search bar while results may be incomplete: "Indexing 42%", "Downloading model · 42%".
    var activityBadge: String? {
        if download.isActive { return L("Downloading model · %@%%", String(Int(download.fraction * 100))) }
        if case .indexing(let done, let total) = status.activity, total > 0 {
            return L("Indexing %@%%", String(Int(Double(done) / Double(total) * 100)))
        }
        if status.paused, status.pending > 0 { return L("Indexing paused") }
        return nil
    }

    /// Why meaning search can't run yet (words still match), or nil.
    var meaningUnavailable: String? {
        guard !download.isReady else { return nil }
        if download.isActive {
            return L("Matching words only until the model has downloaded (%@%%)",
                     String(Int(download.fraction * 100)))
        }
        return L("Matching words only: the model isn't downloaded")
    }

    /// Why results may be incomplete right now, or nil.
    var resultsCaveat: String? {
        if let meaningUnavailable { return meaningUnavailable }
        if case .indexing(let done, let total) = status.activity, total > 0 {
            return L("Still indexing (%@%%): some files aren't in yet",
                     String(Int(Double(done) / Double(total) * 100)))
        }
        if status.pending > 0 {
            return status.pending == 1 ? L("%@ file isn't indexed yet", status.pending.formatted())
                : L("%@ files aren't indexed yet", status.pending.formatted())
        }
        return nil
    }
}
