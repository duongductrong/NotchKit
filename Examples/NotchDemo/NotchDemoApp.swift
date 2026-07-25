import AppKit
import SwiftUI
import NotchKit // remove this line if you copied NotchKit into your app target

// A complete island app. Everything below is content — NotchKit handles the
// window, the silhouette, the hit testing, and the motion.
//
// Run it with `swift run NotchDemo`, then move the pointer to the notch.

// MARK: - Model

@MainActor
@Observable
final class DemoModel {
    var tasks: [String] = ["Indexing workspace", "Running tests"]
    var isWorking = true

    var activityMode: NotchActivityBars.Mode {
        if tasks.isEmpty { return .idle }
        return isWorking ? .active : .paused
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
    private let model = DemoModel()
    private var presenter: NotchPresenter?

    func applicationDidFinishLaunching(_ notification: Notification) {
        var configuration = NotchConfiguration.standard
        configuration.expandedSize = CGSize(width: 520, height: 240)

        let presenter = NotchPresenter(
            configuration: configuration,
            // `nil` would also resolve Reduce Motion for us; passing it
            // explicitly documents the intent.
            motion: .resolved(.standard),
            style: .standard
        )
        self.presenter = presenter

        presenter.install(
            collapsed: { [model] in
                CollapsedBar(model: model, presenter: presenter)
            },
            expanded: { [model] in
                ExpandedPanel(model: model, presenter: presenter)
            }
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

// MARK: - Collapsed

/// Content for the resting pill.
///
/// `NotchCutoutLayout` keeps everything clear of the hardware cutout. Drop it
/// and the centre of this bar becomes invisible on any MacBook.
struct CollapsedBar: View {
    let model: DemoModel
    let presenter: NotchPresenter

    var body: some View {
        NotchCutoutLayout(
            cutoutWidth: presenter.geometry.hasPhysicalNotch ? presenter.geometry.notchWidth : 0,
            gutterWidth: presenter.collapsedGutterWidth,
            // Lets the layout derive an edge inset that clears the pill's
            // semicircular corners for content of any height.
            pillHeight: presenter.geometry.collapsedHeight
        ) {
            NotchActivityBars(
                mode: model.activityMode,
                size: 18,
                tint: presenter.style.foreground
            )
        } trailing: {
            if !model.tasks.isEmpty {
                Text("\(model.tasks.count)")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
        }
    }
}

// MARK: - Expanded

struct ExpandedPanel: View {
    let model: DemoModel
    let presenter: NotchPresenter

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Activity")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(model.isWorking ? "Working" : "Paused")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            if model.tasks.isEmpty {
                Text("Nothing running")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 0) {
                    ForEach(model.tasks, id: \.self) { task in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(model.isWorking ? Color.green : Color.orange)
                                .frame(width: 6, height: 6)
                            Text(task).font(.system(size: 12))
                            Spacer()
                        }
                        .frame(height: 28)

                        if task != model.tasks.last {
                            Divider().opacity(0.15)
                        }
                    }
                }
                // Content inside an open panel eases; it never springs.
                // Overshoot under text makes the text hard to read.
                .animation(presenter.motion.contentMorph, value: model.tasks)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Button(model.isWorking ? "Pause" : "Resume") {
                    model.isWorking.toggle()
                }
                Button("Add task") {
                    model.tasks.append("Task \(model.tasks.count + 1)")
                }
                Spacer()
                Button("Close") { presenter.collapse() }
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
        }
        // No padding here on purpose. The container applies
        // `configuration.expandedContentInsets`, which are derived from the corner
        // radii so content cannot clip against the concave side walls. Padding it
        // again by hand is how you end up with a cramped panel.
    }
}
