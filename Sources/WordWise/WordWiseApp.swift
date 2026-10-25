import AppKit
import SwiftUI
import WordWiseCore

@main
struct WordWiseApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate
    @Stored private var game = Game()

    var body: some Scene {
        Window("WordWise", id: "main") {
            ContentView(game: game)
                .frame(minWidth: 520, minHeight: 620)
                // Pick up list files added to the folders while the app was in the background.
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    game.refreshWordLists()
                }
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Round") { game.newRound() }
                    .keyboardShortcut("n")
            }
            CommandMenu("Word List") {
                Toggle("Built-in (\(WordBank.builtIn.words.count) words)", isOn: Binding(
                    get: { game.wordBank.source == nil },
                    set: { if $0 { game.useBuiltInWordList() } }
                ))
                Divider()
                ForEach(game.bundledLists) { listToggle($0) }
                if !game.userLists.isEmpty {
                    Divider()
                    ForEach(game.userLists) { listToggle($0) }
                }
                Divider()
                Button("Open Other…") { chooseWordList() }
                    .keyboardShortcut("o")
                Button("Show My Word Lists Folder") { showUserFolder() }
            }
        }
    }

    private func listToggle(_ list: WordListFile) -> some View {
        Toggle(list.name, isOn: Binding(
            get: { game.isUsing(list) },
            set: { if $0 { use(list.url) } }
        ))
    }

    private func use(_ url: URL) {
        do {
            try game.useWordList(at: url)
        } catch {
            game.notice = error.localizedDescription
        }
    }

    private func chooseWordList() {
        let panel = NSOpenPanel()
        panel.message = "Choose a text file with one word per line."
        panel.allowedContentTypes = [.plainText]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        use(url)
    }

    /// Opens the folder in Finder, creating it first so there's somewhere to drop new lists.
    private func showUserFolder() {
        try? FileManager.default.createDirectory(at: WordListLibrary.userFolder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(WordListLibrary.userFolder)
    }
}

/// Lets the app come to the front when launched straight from `swift run` without a bundle.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

/// `@State` resolves to SwiftUI's `State()` macro, whose plugin ships only with Xcode. Aliasing the
/// property-wrapper type lets the app build with just the Command Line Tools.
typealias Stored<Value> = SwiftUI.State<Value>
