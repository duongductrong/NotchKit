# Customization

Nothing about an island's content is fixed. The three value types below control
everything else, and each has presets you can take wholesale or tweak field by
field.

## Content: both slots take anything

`install(collapsed:expanded:)` takes plain `@ViewBuilder`s. The icon-and-counter in
the examples is an example, not a contract — a slot can hold artwork, a progress
bar, a chart, controls, live text, or nothing.

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

`NotchCutoutLayout` only exists to keep content out of the cutout. On a display
without one, pass `cutoutWidth: 0` and it degenerates into a leading/trailing bar —
or skip it entirely and lay the pill out yourself.

### Reading state from content

`NotchPresenter` is `@Observable`, so content can branch on `presenter.phase`
without any wiring:

```swift
collapsed: {
    if presenter.phase == .peeking {
        Text("Done!").transition(.opacity)
    } else {
        NotchActivityBars(mode: .active)
    }
}
```

## Sizing: `NotchCollapsedWidth`

The pill's drawn width and its hit target are separate, because a compact pill
should still be easy to hit without being forced wide just to be clickable.

```swift
var config = NotchConfiguration.standard

// Wrap the hardware cutout, extending 44pt past each side. The reserve is where
// your content goes; the middle is behind the notch.
config.collapsedWidth = .wrapCutout(reserve: 44)

// Or ignore the cutout and take a fixed width. Right for displays with no notch,
// where wrapping a *simulated* one leaves a wide pill with an empty middle.
config.collapsedWidth = .fixed(220)

// Invisible margin around the pill, purely for aiming.
config.collapsedHitPadding = 6
```

`presenter.collapsedGutterWidth` resolves the usable per-side width for whichever
strategy is active — pass that to `NotchCutoutLayout` rather than recomputing.

To size the pill to its content, measure the content and feed the result into
`.fixed(_:)`. There is deliberately no automatic intrinsic mode: the pill width
feeds the morph, and a width that changes as content changes makes the morph's
start point move underneath it.

## `NotchConfiguration`

| Field | Default | Notes |
|---|---|---|
| `expandedSize` | 540 × 260 | Also the window size — the window never resizes, so pick the largest panel you will ever show. |
| `collapsedWidth` | `.wrapCutout(reserve: 44)` | See above. |
| `collapsedHitPadding` | 6 | Invisible aiming margin. |
| `shadowInsetHorizontal` / `Bottom` | 18 / 22 | Transparent room inside the window for the shadow to fall into. |
| `expandedTopCornerRadius` | 22 | Concave curl. Ignored on displays with no cutout. |
| `expandedBottomCornerRadius` | 22 | Convex fillet. |
| `expandedContentInsetsOverride` | `nil` | `nil` derives insets that clear the silhouette. |
| `expandsOnHover` | `true` | |
| `hoverOpenDelay` | 0.15s | Filters pointer transits. |
| `hoverCancelGrace` | 0.10s | Filters pointer jitter at the cutout edge. |
| `collapsesOnPointerExit` | `true` | Hover-opened islands only. |
| `collapsesOnOutsideClick` | `true` | Also reposts the click. |
| `hapticOnHoverOpen` | `true` | No-op without a Force Touch trackpad. |
| `pointerSampleInterval` | 0.05s | 20Hz. This monitor runs for your app's whole lifetime. |

Presets: `.standard`, `.clickOnly`, `.statusOnly`, `.standalone(pillWidth:)`.

Both hover delays matter and they do different jobs — see
[motion.md](motion.md#hover-needs-two-delays).

## `NotchStyle`

```swift
let presenter = NotchPresenter(style: .standard)
```

| Preset | Ink | Use |
|---|---|---|
| `.standard` | pure black | Merges with the physical cutout. |
| `.openIsland` | `#0D0D0F` + cream | Open Island's brand palette; reads as its own surface. |
| `.contrast` | pure black, stronger edge | Legible over bright or busy wallpapers. |
| `.translucent` | 72% black | Nice over static wallpaper; cannot merge with the cutout. |

**Why pure black is the default.** The physical notch is opaque housing, not
screen — it emits nothing, so it is as black as the display can go. Any lifted
black beside it is a visibly *lighter* patch, and the pill reads as a grey
rectangle bracketing the cutout instead of one continuous shape. Subtle in a
screenshot, obvious in person.

The hairline exists for the opposite reason: pure black on a dark wallpaper has no
edge at all, and the panel dissolves into the desktop. A few percent of white
rescues the silhouette without being visible on light backgrounds.

```swift
var style = NotchStyle.standard
style.hairline = .white.opacity(0.14)
style.shadowRadius = 20
style.foreground = .white
```

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

## Custom silhouette

Implement `Shape` with `animatableData` so radii interpolate instead of jump-cutting,
and clamp against the rect — mid-morph the rect can be far smaller than the radius,
and un-clamped curves self-intersect into a one-frame flicker.

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

If your shape needs to serve *both* phases, give it a parameter that degenerates
into the collapsed form the way `NotchShape.topCornerRadius == 0` does. Otherwise
you are back to swapping shape types, and the transition stops reading as a morph.

## Custom continuous indicator

`NotchActivityBars` is one provided glyph, not the only option. The pattern worth
copying is *how* it animates: `CAShapeLayer` + `CABasicAnimation` on
`transform.scale.y`, wrapped in `NSViewRepresentable`.

A continuous animation driven from SwiftUI (`TimelineView`, or a repeating
`withAnimation`) re-evaluates the view body every frame, forever, for decoration
nobody is looking at. Core Animation describes it once and the render server
interpolates it with zero main-thread work per frame.

Read `Sources/NotchKit/NotchActivityBars.swift` — it is ~100 lines and commented as
a template. Two things to carry over:

- Re-arm in `viewDidMoveToWindow()`. Core Animation strips animations from layers
  that leave the window, so the glyph otherwise freezes after a Space switch.
- Stagger `beginTime` across sibling layers, or a multi-bar glyph pumps in unison
  and reads as one block rather than a wave.

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

- **Window size.** Fixed at expanded size for the island's whole life. See
  [architecture.md](architecture.md#why-the-window-never-resizes).
- **Phase count.** Three states. Every extra phase multiplies the animation matrix,
  and users cannot perceive many distinct states in a 40pt strip. Add a property
  your content reads instead.
- **Panel height per state.** Set `expandedSize` to the largest case and lay content
  out inside it. For content-driven height, measure with a `PreferenceKey` and size
  the *content* — see [recipes.md](recipes.md#content-driven-panel-height).
