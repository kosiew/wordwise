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
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Round") { game.newRound() }
                    .keyboardShortcut("n")
            }
        }
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
