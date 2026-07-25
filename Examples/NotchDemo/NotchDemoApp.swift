import AppKit
import Foundation
import SwiftUI
import NotchKit // remove this line if you copied NotchKit into your app target

// A complete island app that hosts three completely different islands.
//
// Run it with `swift run NotchDemo`, move the pointer to the notch, then use the
// buttons in the panel to switch presets. Watch the window resize, the ink
// change, and the springs retime — all by assigning to `presenter`.
//
// The shell below is deliberately tiny. Everything that makes an island *look
// like something* lives in `IslandPreset` values: VibeCodeIsland.swift,
// DropNotchIsland.swift, NowPlayingIsland.swift.

// MARK: - Model

@MainActor
@Observable
final class DemoModel {

    /// Held so content can read live geometry and drive the island. NotchKit does
    /// not retain you, so something has to own this — see `AppDelegate`.
    let presenter: NotchPresenter

    private(set) var presetIndex = 0
    var preset: IslandPreset { IslandPreset.all[presetIndex] }

    // Vibe Code
    var steps: [Step] = [
        Step(title: "Indexing workspace", state: .done),
        Step(title: "Running tests", state: .running),
        Step(title: "Reviewing diff", state: .queued),
    ]
    var isRunning = true
    var completedSteps: Int { steps.filter { $0.state == .done }.count }

    // Drop Notch
    var files: [String] = []
    var isDropTargeted = false

    // Now Playing
    var track = Track(title: "Midnight Bezel", artist: "The Cutouts")
    var isPlaying = true

    init(presenter: NotchPresenter) {
        self.presenter = presenter
    }

    // MARK: Preset switching

    /// Swapping a preset onto a live presenter is an ordinary thing to do. The
    /// window repositions itself when `configuration` changes size, and style and
    /// motion are picked up on the next render — no reinstall, no teardown, no
    /// flicker. Content follows because the slot closures read `preset`, and
    /// `presetIndex` is observed.
    func select(_ index: Int) {
        guard IslandPreset.all.indices.contains(index) else { return }
        presetIndex = index
        presenter.configuration = preset.configuration
        // `.resolved` keeps Reduce Motion honoured across the swap; passing the
        // preset's curves raw would quietly re-enable animation for users who
        // turned it off.
        presenter.motion = .resolved(preset.motion)
        presenter.style = preset.style
    }

    // MARK: Mutations

    func addStep() {
        steps.append(Step(title: "Step \(steps.count + 1)", state: .queued))
    }

    func addFiles(_ urls: [URL]) {
        files.append(contentsOf: urls.map(\.lastPathComponent))
    }

    struct Step: Identifiable, Hashable {
        enum State: Hashable { case done, running, queued }
        let id = UUID()
        var title: String
        var state: State
    }

    struct Track: Hashable {
        var title: String
        var artist: String
    }
}

// MARK: - App

/// `@MainActor` because every AppKit delegate callback already arrives on the
/// main thread, and without it the compiler cannot see that — so touching
/// main-actor state from stored-property initialisers is rejected.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // Hold both strongly: the presenter owns the window, and nothing else
    // retains it. Let it go and the island silently disappears.
    private var presenter: NotchPresenter?
    private var model: DemoModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let first = IslandPreset.all[0]

        let presenter = NotchPresenter(
            configuration: first.configuration,
            // `nil` would also resolve Reduce Motion for us; passing it
            // explicitly documents the intent.
            motion: .resolved(first.motion),
            style: first.style
        )
        let model = DemoModel(presenter: presenter)
        self.presenter = presenter
        self.model = model

        presenter.install(
            collapsed: { CollapsedShell(model: model) },
            expanded: { ExpandedShell(model: model) }
        )
    }
}

@main
enum NotchDemo {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        // `NSApplication.delegate` is unowned, so the delegate needs a strong
        // reference that outlives `main` — hence the local held across `run()`.
        let delegate = AppDelegate()
        app.delegate = delegate
        // The programmatic equivalent of `LSUIElement`: no Dock icon, no menu
        // bar, never steals focus. An island is an accessory, not an app window.
        app.setActivationPolicy(.accessory)
        app.run()
        _ = delegate
    }
}
