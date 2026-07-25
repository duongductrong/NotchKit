import NotchKit
import SwiftUI

/// One island personality, as a value.
///
/// This is the split NotchKit is built around, made concrete. The library owns
/// the window, the silhouette, hit testing and the motion. A preset owns *what
/// shows* — and that includes the panel size, the palette and the curves, not
/// just the views.
///
/// The three presets in this folder share no content code, look nothing alike,
/// and needed no changes to NotchKit to exist. That is the test of whether a base
/// component is actually generic: you should be able to add a fourth here and
/// never open `Sources/`.
///
/// ## Why `AnyView`
///
/// Only because these live together in one array and each slot returns a
/// different concrete type. Your app will not need it — you have one island, so
/// its slots can be plain `some View`. Don't copy this bit.
struct IslandPreset: Identifiable {
    let id: String
    let name: String

    // Everything NotchKit takes as configuration is per-preset. Swapping presets
    // resizes the window, repaints the ink, and retimes the springs.
    let configuration: NotchConfiguration
    let motion: NotchMotion
    let style: NotchStyle

    // `@MainActor` because these read observable UI state. Without it the closure
    // type is nonisolated and the compiler rejects touching the model, which is
    // correct — these only ever run inside a SwiftUI body.

    /// Collapsed pill, left of the cutout.
    let collapsedLeading: @MainActor (DemoModel) -> AnyView
    /// Collapsed pill, right of the cutout.
    let collapsedTrailing: @MainActor (DemoModel) -> AnyView
    /// The expanded panel.
    let expanded: @MainActor (DemoModel) -> AnyView

    static var all: [IslandPreset] {
        [.morphInspector, .vibeCode, .dropNotch, .nowPlaying]
    }
}

