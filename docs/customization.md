# Customization

NotchKit owns the window, the silhouette, hit testing, and the motion. You own
everything you can see inside it.

That split is the whole design. If you find yourself wanting to change something
in `Sources/` to get the island you want, that is a gap in this document or a gap
in the library — [open an issue](https://github.com/duongductrong/NotchKit/issues).

- [Content: three slots, anything in them](#content-three-slots-anything-in-them)
- [Packaging a look as a value](#packaging-a-look-as-a-value)
- [The collapsed pill](#the-collapsed-pill)
- [The expanded panel](#the-expanded-panel)
- [Indicators: `NotchBars`](#indicators-notchbars)
- [`NotchStyle`](#notchstyle)
- [`NotchMotion`](#notchmotion)
- [Changing everything at runtime](#changing-everything-at-runtime)
- [Custom silhouette](#custom-silhouette)
- [Your own continuous indicator](#your-own-continuous-indicator)
- [Multi-display](#multi-display)
- [What is not configurable, and why](#what-is-not-configurable-and-why)

## Content: three slots, anything in them

There are three places content goes: left of the cutout, right of the cutout, and
the expanded panel. All three are plain SwiftUI. The icon-and-counter you see in
examples is an example, not a contract.

```swift
presenter.install(
    collapsed: {
        NotchCutoutLayout(
            cutoutWidth: presenter.geometry.hasPhysicalNotch ? presenter.geometry.notchWidth : 0,
            gutterWidth: presenter.collapsedGutterWidth,
            pillHeight: presenter.geometry.collapsedHeight
        ) {
            // leading gutter — anything
            HStack(spacing: 4) {
                Image(nsImage: artwork).resizable().frame(width: 18, height: 18)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                Text(track.title).lineLimit(1)
            }
        } trailing: {
            // trailing gutter — anything
            ProgressView(value: fraction).frame(width: 40)
        }
    },
    expanded: { MyWholeInterface() }
)
```

`NotchCutoutLayout` exists only to keep content out of the cutout. On a display
without one, pass `cutoutWidth: 0` and it degenerates into a leading/trailing bar —
or skip it and lay the pill out yourself.

### Reading state from content

`NotchPresenter` is `@Observable`, so content branches on `presenter.phase` with no
wiring:

```swift
collapsed: {
    if presenter.phase == .peeking {
        Text("Done!").transition(.opacity)
    } else {
        NotchBars(.wave())
    }
}
```

## Packaging a look as a value

Once an app has more than one island — a build-status island and a drop-shelf
island, say — the useful move is to stop thinking about "configuring NotchKit" and
start treating a whole island as a value:

```swift
struct IslandPreset: Identifiable {
    let id: String
    let name: String

    // Everything NotchKit takes is per-preset, not global.
    let configuration: NotchConfiguration
    let motion: NotchMotion
    let style: NotchStyle

    // `@MainActor` because these read observable UI state.
    let collapsedLeading:  @MainActor (AppModel) -> AnyView
    let collapsedTrailing: @MainActor (AppModel) -> AnyView
    let expanded:          @MainActor (AppModel) -> AnyView
}
```

Then each island is a `static let` in its own file, and the shell that installs
them knows nothing about any of them:

```swift
presenter.install(
    collapsed: { model.preset.collapsedLeading(model) },   // reads `preset` → observed
    expanded:  { model.preset.expanded(model) }
)
```

Because the slots read observable state, swapping `preset` re-renders the island —
no reinstall, no teardown.

**[`Examples/NotchDemo`](../Examples/NotchDemo) is exactly this**, with three
presets that share no content code:

| Preset | Panel | Ink | Motion | Shows off |
|---|---|---|---|---|
| Vibe Code | 520 × 250, wide and short | hardware black | `.standard` | Four-bar equaliser, step list, progress |
| Drop Notch | 400 × 300, narrow and tall | `.warmPaper` | `.playful` | Real `dropDestination`, tighter pill, generous hit padding |
| Now Playing | 460 × 190, full-bleed | `.contrast` | `.crisp` | `.canvas` config — artwork under the cutout, no insets |

Run `swift run NotchDemo` and switch between them in the panel. The `AnyView` in
that struct is only there because three presets with different concrete view types
live in one array; a single island needs `some View`.

## The collapsed pill

The pill's **drawn width** and its **hit target** are separate, because a compact
pill should still be easy to hit without being forced wide to be clickable.

```swift
var config = NotchConfiguration.standard

// Wrap the hardware cutout, extending 44pt past each side. The reserve is where
// your content goes; the middle is behind the notch.
config.collapsedWidth = .wrapCutout(reserve: 44)

// Or ignore the cutout and take a fixed width. Right for displays with no notch,
// where wrapping a *simulated* one leaves a wide pill with an empty middle.
config.collapsedWidth = .fixed(220)

// Invisible margin around the pill, purely for aiming.
config.collapsedHitPadding = 14

// Slight concave curl at the pill's top corners, so it flares into the bezel the
// way the open panel does. 0 for a dead-flat top.
config.collapsedTopCornerRadius = 6
```

### `collapsedTopCornerRadius`

The physical cutout does not meet the bezel at a right angle, so a dead-flat pill
top reads as a black rectangle *parked* under the notch rather than as part of it. A
few points of the same curl the expanded panel has fuses the two.

Keep it well under `expandedTopCornerRadius`. The two are seen at very different
scales, and the same number is a gentle flare across a 260pt panel and a gouge
across a 38pt pill. `NotchShape` clamps the top radius to a quarter of the height
either way, so on current hardware anything above ~9.5pt is silently pinned and
raising it further does nothing.

Forced to `0` on displays with no hardware cutout — the same rule
`expandedTopCornerRadius` follows, and for the same reason: there is nothing there
to fuse with, so the curl reads as a rendering fault.

`presenter.collapsedGutterWidth` resolves the usable per-side width for whichever
strategy is active — pass that to `NotchCutoutLayout` rather than recomputing.

`NotchCutoutLayout` also takes:

| Parameter | Default | Notes |
|---|---|---|
| `edgeInset` | `nil` | `nil` derives half the pill height — safe for content of *any* height, bar the last ~0.6pt of the corner once `collapsedTopCornerRadius` shifts the wall inboard. |
| `alignment` | `.center` | `.firstTextBaseline` when the two sides hold text at different sizes. |

To size the pill to its content, measure the content and feed the result into
`.fixed(_:)`. There is deliberately no automatic intrinsic mode: the pill width is
the morph's start point, and a start point that moves as content changes makes the
morph shift under itself.

## The expanded panel

```swift
var config = NotchConfiguration.standard
config.expandedSize = CGSize(width: 400, height: 300)
config.expandedBottomCornerRadius = 28
config.expandedTopReserve = .always
config.expandedContentAlignment = .center
config.expandedContentInsetsOverride = EdgeInsets(top: 4, leading: 24, bottom: 18, trailing: 24)
```

### `expandedTopReserve`

The top strip of an open panel sits **behind the physical notch** on a MacBook, so
anything drawn there is invisible — and invisible only on notched Macs, which is
how it survives development on an external monitor.

Reserving a row fixes it. Reserving unconditionally wastes space where nothing is
in the way. So it is a policy:

| Policy | Reserves | For |
|---|---|---|
| `.cutoutOnly` *(default)* | pill height, only where a cutout exists | Lists and text. Never wrong; occasionally different between displays. |
| `.always` | pill height, everywhere | Layouts that must be pixel-identical on every display. |
| `.fixed(h)` | exactly `h` | A panel whose own header already clears the cutout, or a deliberately larger gap. |
| `.none` | nothing | Full-bleed artwork, video, a blurred backdrop. |

### Insets

`nil` (the default) derives insets from the corner radii so content always clears
the silhouette. This matters more than it sounds: a concave top corner makes the
panel **widest at its very top edge**, tapering inward until the wall settles at
`x = topRadius`. Content padded by a plain 20pt against a 22pt radius is *outside
the shape* along the upper flanks and clips — which reads as a rendering glitch,
not a padding mistake.

Override it when you know better; set it to `.zero` for full-bleed. The container
clips content to `NotchShape` either way, so you cannot spill outside the
silhouette — you can only end up with content hidden in the flanks.

### `.canvas`

`NotchConfiguration.canvas` bundles `.none` reserve with zero insets, for artwork
that reads fine partly occluded:

```swift
var config = NotchConfiguration.canvas
config.expandedSize = CGSize(width: 460, height: 190)
```

Position anything that must be *read* by hand — see `NowPlayingIsland.swift`.

### Full `NotchConfiguration` reference

| Field | Default | Notes |
|---|---|---|
| `expandedSize` | 540 × 260 | Panel content size. Also drives the window size. |
| `collapsedWidth` | `.wrapCutout(reserve: 44)` | See above. |
| `collapsedHitPadding` | 6 | Invisible aiming margin. |
| `shadowInsetHorizontal` / `Bottom` | 20 / 24 | **Floor** for the transparent room inside the window. The margin actually reserved is `max(this, style.shadowReach*)` — see `shadowInsets(fitting:)`. |
| `collapsedTopCornerRadius` | 6 | Slight curl on the resting pill. Clamped to a quarter of the pill height (~9.5pt); forced to 0 on displays with no cutout. |
| `expandedTopCornerRadius` | 22 | Concave curl. Forced to 0 on displays with no cutout. |
| `expandedBottomCornerRadius` | 22 | Convex fillet. |
| `expandedContentInsetsOverride` | `nil` | `nil` derives insets that clear the silhouette. |
| `expandedTopReserve` | `.cutoutOnly` | See above. |
| `expandedContentAlignment` | `.top` | Where content sits below the reserve. |
| `expandsOnHover` | `true` | |
| `hoverOpenDelay` | 0.15s | Filters pointer transits. |
| `hoverCancelGrace` | 0.10s | Filters pointer jitter at the cutout edge. |
| `collapsesOnPointerExit` | `true` | Hover-opened islands only. |
| `collapsesOnOutsideClick` | `true` | Also reposts the click. |
| `hapticOnHoverOpen` | `true` | No-op without a Force Touch trackpad. |
| `pointerSampleInterval` | 0.05s | 20Hz. This monitor runs for your app's whole lifetime. |

Presets: `.standard`, `.clickOnly`, `.statusOnly`, `.canvas`,
`.standalone(pillWidth:)`.

Both hover delays matter and they do different jobs — see
[motion.md](motion.md#hover-needs-two-delays).

## Indicators: `NotchBars`

A row of bars whose heights animate continuously. Whether that reads as an
equaliser, a level meter, or a breathing beacon is entirely in the numbers.

```swift
NotchBars(.wave(count: 4, low: 0.22, high: 1, period: 0.7))
```

| Field | Default | Notes |
|---|---|---|
| `levels` | — | Resting height per bar, `0...1`. **Bar count is `levels.count`.** |
| `peaks` | `nil` | Target height per bar. `nil`, or equal to its level, leaves that bar static. |
| `barWidth` | 2.5 | |
| `spacing` | 3 | |
| `cornerRadius` | `nil` | `nil` gives capsule ends. |
| `height` | 14 | Height at level `1`, and the view's height. |
| `period` | 0.9s | One full level → peak → level cycle. |
| `stagger` | 0.15s | Delay per bar. `0` makes them pump in unison; a small value makes a wave. |
| `curve` | `.easeInOut` | Also `.linear`, `.easeIn`, `.easeOut`. |
| `tint` | `.white` | |
| `label` | `nil` | VoiceOver label. `nil` marks it decorative. |

There is no separate bar-count property on purpose — a count paired with a heights
array is the kind of thing that silently breaks the first time someone adds a bar.

### No app states in here

NotchKit ships `.steady(_:)` and `.wave(count:...)` — names that describe *shape*.
It deliberately ships no `.recording`, `.building`, or `.paused`, because those are
your app's states, and a library that names them makes every consumer either adopt
one app's vocabulary or fight it.

Define them where the meaning lives:

```swift
private extension NotchBarsStyle {
    static func running(tint: Color) -> NotchBarsStyle {
        wave(count: 4, low: 0.22, high: 1, height: 13, period: 0.7, stagger: 0.11, tint: tint)
    }

    static func paused(tint: Color) -> NotchBarsStyle {
        // No peaks, so no animation object is created at all — a paused indicator
        // should cost nothing, not idle at 60fps.
        steady([0.55, 0.3, 0.55, 0.3], height: 13, tint: tint)
    }
}
```

`isAnimated` tells you whether a style has anywhere to go, and `level(at:)` /
`peak(at:)` clamp and bounds-check, so a style assembled from live data (audio
levels, download progress) degrades to a sensible bar instead of trapping.

Set `label` when the bars are the **only** thing conveying state — a silent
animation is invisible to a screen reader.

## `NotchStyle`

| Preset | Ink | Use |
|---|---|---|
| `.standard` | pure black | Merges with the physical cutout. |
| `.warmPaper` | `#0D0D0F` + cream | Reads as its own surface beside the cutout. |
| `.contrast` | pure black, deeper shadow | Legible over bright or busy wallpapers. |
| `.translucent` | 72% black | Nice over static wallpaper; cannot merge with the cutout. |

**Why pure black is the default.** The physical notch is opaque housing, not
screen — it emits nothing, so it is as black as the display can go. Any lifted
black beside it is a visibly *lighter* patch, and the pill reads as a grey
rectangle bracketing the cutout instead of one continuous shape. Subtle in a
screenshot, obvious in person.

**No stroked edge, ever.** The silhouette is ink and shadow only, in both phases.
A rim is what makes an island read as something pasted on top of the display: a
centred stroke puts half its width outside the fill, so it outlines the shape
against the desktop and, while collapsed, traces the hardware cutout itself.
Native is unbroken black — depth comes from `shadowColor` on the open panel, which
is already suppressed while collapsed for the same reason.

If one particular island really does want an edge, stroke it inside your own
content. That keeps the choice local instead of putting a rim on every island.

**The shadow is three knobs and two passes.** You set `shadowColor`,
`shadowRadius`, and `shadowOffsetY`; what gets drawn is a tight `contactShadow`
that keeps the panel touching the screen and a wide `ambientShadow` that fades
out, both derived from those three. One Gaussian cannot do both jobs — wide enough
to look soft and it reads as a uniform grey halo with the panel hovering above it.

You do not have to reserve room for it. `shadowReachHorizontal` and
`shadowReachBelow` say how far the falloff runs — about `2 × radius`, plus the
offset downward — and the window reserves at least that much, so raising the radius
grows the window rather than truncating the gradient against its edge.

```swift
var style = NotchStyle.standard
style.shadowRadius = 44        // window grows to fit; nothing clips
style.shadowOffsetY = 24
style.foreground = .white
style.colorScheme = nil   // inherit the system scheme instead of forcing dark
```

`colorScheme` defaults to `.dark` because a dark island with Light Mode content is
the most common way to make text vanish: `.secondary` and every stock control
resolve to near-black against near-black ink, and only for users who happen to be
in Light Mode. Set `nil` only if you deliberately built a light island.

## `NotchMotion`

Every curve, delay, and scale. Presets: `.standard`, `.crisp` (utility, high
frequency), `.playful` (consumer), `.reduced` (accessibility).

```swift
// .resolved swaps in .reduced when the system asks for less motion.
let presenter = NotchPresenter(motion: .resolved(.playful))
```

Honouring Reduce Motion is not optional for an island: it sits at the edge of
vision and animates unprompted, which is exactly the pattern that causes
discomfort. `.reduced` keeps fades and removes every spring and scale.

Full parameter reference and how to design a new set: [motion.md](motion.md).

## Changing everything at runtime

All three value types are `var`s on the presenter. Assign and the island updates:

```swift
presenter.configuration = otherPreset.configuration   // resizes the window if needed
presenter.motion = .resolved(otherPreset.motion)
presenter.style = otherPreset.style
```

Changing `configuration` to something with a different `expandedSize` repositions
the window immediately — that is what lets an app swap between differently-sized
panels without tearing the island down. It is a discrete event, deliberately not
animated; see [architecture.md](architecture.md#why-the-window-never-resizes) for
why the window must never animate its own frame.

Keep `.resolved(_:)` in the path when you swap motion, or you will quietly
re-enable animation for users who turned it off.

## Custom silhouette

Implement `Shape` with `animatableData` so radii interpolate instead of
jump-cutting, and clamp against the rect — mid-morph the rect can be far smaller
than the radius, and un-clamped curves self-intersect into a one-frame flicker.

```swift
struct SquaredIslandShape: Shape {
    var cornerRadius: CGFloat = 12

    var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let r = min(cornerRadius, rect.width / 4, rect.height / 2)
        return Path(roundedRect: rect, cornerRadius: r)
    }
}
```

Swap it into `NotchContainer`'s surface. Nothing else changes — the window, hit
testing, and motion layers do not know which shape is in use.

If your shape needs to serve *both* phases, give it a parameter that carries it
continuously into the collapsed form the way `NotchShape.topCornerRadius` does —
small at rest, larger when open, and degenerate at `0`. Otherwise you are back to
swapping shape types, and the transition stops reading as a morph.

## Your own continuous indicator

`NotchBars` is one component, not the only shape a live indicator can take. When
you build another, the part worth copying is *how* it animates: `CAShapeLayer` +
`CABasicAnimation`, wrapped in `NSViewRepresentable`.

A continuous animation driven from SwiftUI (`TimelineView`, or a repeating
`withAnimation`) re-evaluates the view body every frame, forever, for decoration
nobody is looking at. Core Animation describes it once and the render server
interpolates it with zero main-thread work per frame.

Read [`Sources/NotchKit/NotchBars.swift`](../Sources/NotchKit/NotchBars.swift) —
it is short and commented as a template. Four things to carry over:

- **Animate a transform, not geometry.** `transform.scale.y` is a pure compositor
  operation. Animating `path` or `bounds` re-rasterises every frame and gives up
  most of the win.
- **Re-arm in `viewDidMoveToWindow()`.** Core Animation strips animations from
  layers that leave the window, so the glyph otherwise freezes after a Space
  switch or a window reorder.
- **Update `contentsScale` in `viewDidChangeBackingProperties()`.** The island
  follows the pointer between displays, which can mean Retina → non-Retina.
- **Stagger `beginTime` across sibling layers**, or a multi-part glyph pumps in
  unison and reads as one block rather than a wave.

Use `TimelineView` only when each frame genuinely needs data SwiftUI owns — a live
countdown, a waveform from an audio buffer.

## Multi-display

```swift
// Persist the stable ID, never a CGDirectDisplayID — those get recycled on
// hotplug and will eventually route the island to a different monitor.
let options = NSScreen.screens.map { ($0.notch_stableID, $0.localizedName) }
presenter.preferredScreenID = savedID
```

Setting it repositions immediately. If the saved display is gone, the built-in
screen-change observer falls back to automatic on its own.

## What is not configurable, and why

- **The window resizing mid-transition.** The morph happens entirely inside a
  fixed window; AppKit frame animation and SwiftUI springs use different curves
  and the mismatch janks. Swapping `configuration` between panels is fine —
  animating the window frame is not. See
  [architecture.md](architecture.md#why-the-window-never-resizes).
- **Phase count.** Three states. Every extra phase multiplies the animation
  matrix, and users cannot perceive many distinct states in a 40pt strip. Add a
  property your content reads instead.
- **Panel height per state.** Set `expandedSize` to the largest case and lay
  content out inside it. For content-driven height, measure with a `PreferenceKey`
  and size the *content* — see
  [recipes.md](recipes.md#content-driven-panel-height).
