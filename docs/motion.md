# Motion

How to reason about island motion instead of guessing numbers.

## The parameters, actually explained

SwiftUI's `.spring(response:dampingFraction:blendDuration:)`:

**`response`** — the spring's natural period: roughly how long the bulk of the
travel takes. It is *not* a duration; a spring keeps settling after `response`
elapses. Practical range for an island:

| response | Feel |
|---|---|
| 0.20–0.28 | Snappy, almost instant. Small elements, hover states. |
| 0.30–0.45 | The sweet spot for a panel arriving. |
| 0.50–0.60 | Deliberate, cinematic. Starts to feel like loading. |
| > 0.60 | The UI feels like it is thinking. Avoid for anything on the critical path. |

**`dampingFraction`** — the personality dial. How much overshoot:

| damping | Overshoot | Use for |
|---|---|---|
| 1.0 | none (critically damped) | Correct and lifeless. Utility UI, Reduce Motion. |
| 0.80–0.85 | one, barely perceptible | Default for a content-bearing panel. |
| 0.60–0.75 | visible, springy | Consumer-facing, personality wanted. |
| 0.40–0.55 | pronounced bounce | Attention bumps only, where the bounce *is* the message. |

The reason a content panel wants ~0.8 and not 0.6: visible ringing under text
makes the text hard to read while it settles. Bounce is fine on a glyph, costly
on a paragraph.

**`blendDuration`** — how a *replacing* animation blends with one still in flight.
`0` is right for phase transitions: you want the new curve to take over cleanly.
Non-zero is for continuously-retargeted values (drag following a finger).

`Animation.smooth(duration:)` is a monotonic ease with no overshoot — the correct
tool for a departure.

## The default set

These are the curves `NotchMotion.standard` ships with. They are not arbitrary —
each one is picked for what that particular transition has to communicate:

| Transition | Curve | Why |
|---|---|---|
| expand | `.spring(response: 0.42, dampingFraction: 0.80)` | Arriving. Slight overshoot reads as physical. |
| collapse | `.smooth(duration: 0.30)` | Leaving. Monotonic — see asymmetry below. |
| peek | `.spring(response: 0.30, dampingFraction: 0.50)` | Attention. The bounce is the point. |
| hover | `.spring(response: 0.38, dampingFraction: 0.80)` | Matches expand so hover feels like the start of it. |
| content morph | `.timingCurve(0.4, 0, 0.2, 1, duration: 0.45)` | Material standard easing. Content eases, never springs. |
| highlight | `.easeInOut(duration: 0.15)` | Immediate without strobing. |

Scalars: `hoverScale 1.028`, `peekScale 1.04`, `expandedUnmountDelay 0.36s`.

### Content choreography

The shape morph and the content fade are separate on purpose — different properties,
deliberately sequenced rather than racing:

| Field | Default | Why |
|---|---|---|
| `contentRevealDelay` | 0.08s | Head start for the shape. Without it, panel text fades up while the shape is still pill-sized and is visibly squeezed into a sliver. |
| `contentRevealDuration` | 0.22s | Fits inside the 0.42s morph, so the panel never sits fully sized with half-visible content. |
| `contentHideDuration` | 0.12s | Quicker than the reveal and never delayed — outgoing content must be gone before the shape closes over it, or it looks crushed. |
| `expandedUnmountDelay` | 0.36s | Strictly longer than `collapse`, or content tears down mid-morph and the panel flashes empty. |

`NotchMotion.contentFade(isIncoming:)` returns the right curve for each direction.
The asymmetry is the same principle as expand-vs-collapse: the thing arriving can
afford to take its time, the thing leaving cannot.

### Hover needs two delays

Not strictly motion, but the same "feel" budget, and the second one is the one
people omit:

- `hoverOpenDelay` (~0.15s) filters **transits**. The pointer crosses the top of the
  screen constantly en route to the menu bar; opening instantly means the island
  flaps at people who were never looking at it.
- `hoverCancelGrace` (~0.10s) filters **jitter**. The cutout edge is exactly where a
  pointer wobbles in and out. Cancel on the first exit and a user holding still at
  the boundary restarts the timer forever — the island never opens and feels haunted
  rather than slow.

Note how small the scales are. At notch size anything past ~1.05 visibly clips
against the screen edge — the island has no room to grow upward.

## The asymmetry principle

**Opening and closing must not share a curve.**

Opening is arrival: a spring's overshoot reads as mass and makes the panel feel
responsive. Closing is departure, and a spring on the way out means the shape
bounces *back toward the viewer* after they have already dismissed it. It reads as
the UI arguing with the user.

This is the single most common motion mistake in hand-rolled islands, because
reusing one animation constant looks like good hygiene. `NotchMotionTests` pins
the asymmetry so nobody "simplifies" it away.

The same logic applies to any dismissal: sheets, popovers, toasts.

## What is cheap to animate

| Property | Cost | Notes |
|---|---|---|
| `opacity` | free | Pure compositor. |
| `scaleEffect` | free | Pure compositor. |
| `CATransform3D` | free | Runs on the render server, no main thread. |
| corner radius via `animatableData` | cheap | Path rebuild per frame, small path. |
| `frame` / layout size | **expensive** | Re-runs SwiftUI layout for the subtree every frame. |
| window frame | **expensive + janky** | Also a second animator. See [architecture.md](architecture.md). |
| `blur`, `shadow` radius | expensive | Off-screen render pass per frame. |

The island transition therefore animates only opacity, scale, and corner radius.
Nothing that changes layout size moves during a transition.

## Continuous vs. transitional motion

Two different problems; the mistake is using one tool for both.

**Transitional** — a state change, runs once, sub-second. SwiftUI's
`.animation(_, value:)` is exactly right.

**Continuous** — a pulsing dot, an activity glyph. Runs for minutes or hours in a
strip the user is not looking at. Driving that from SwiftUI (`TimelineView`, or a
repeating `withAnimation`) re-evaluates the view body every frame, forever — a
permanent battery cost for decoration.

Use Core Animation: describe the animation once, and the render server
interpolates it with **zero** per-frame main-thread work. `NotchBars` is
the worked example; it animates `transform.scale.y` only, because animating
`path` or `bounds` re-rasterises every frame and gives up most of the win.

Two things to remember with CA animations:
- Core Animation strips animations from layers that leave the window. Re-arm in
  `viewDidMoveToWindow()`, or the glyph freezes after a Space switch or window
  reorder.
- Stagger `beginTime` across sibling layers, or a multi-bar glyph pumps in unison
  and reads as one block rather than a wave.

`TimelineView` is right only when each frame needs data SwiftUI owns — a live
countdown, a waveform from an audio buffer.

## Designing a new motion set

1. **Start from a preset**, not from zero. `.standard`, `.crisp` (utility,
   high-frequency), `.playful` (consumer, character).
2. **Fix `response` first**, with damping at 1.0. Get the *timing* right while
   there is no overshoot to distract you.
3. **Then lower damping** until it feels alive, and stop one step before you can
   see it ring. If content is legible throughout, you are in range.
4. **Set collapse independently** as a `.smooth` of roughly 0.7× the expand
   response. It should feel slightly quicker — departures that linger feel
   sticky.
5. **Check `expandedUnmountDelay > collapse duration`**, or the fade tears.
6. **Test the rapid path**: open → close → open as fast as you can click. Most
   motion bugs only appear under overlap.
7. **Test with Reduce Motion on.**

## Reduce Motion is not optional here

An island lives at the edge of vision and animates unprompted — precisely the
pattern that triggers discomfort and nausea for motion-sensitive users.

`NotchMotion.resolved()` swaps in `.reduced` automatically:

```swift
let presenter = NotchPresenter(motion: .resolved(.playful))
```

`.reduced` keeps cross-fades (a fade is not vestibular motion) and removes every
spring and every scale — `hoverScale` and `peekScale` both become exactly 1.0.
Scaling is the part that causes the problem; fading is fine.

To react to a live change, observe
`NSWorkspace.shared.notificationCenter` for
`NSWorkspace.accessibilityDisplayOptionsDidChangeNotification` and reassign
`presenter.motion`.
