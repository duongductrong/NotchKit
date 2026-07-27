# MorphSection & Product Element Inspector

**NotchKit** centers around one core visual primitive: a **single `NotchShape` surface** (`MorphSection`) that morphs smoothly between a collapsed pill and an expanded panel. 

Rather than treating the island as an opaque container, NotchKit models every sub-element of the morph as an inspected detail of the product with a dedicated mission, clear arguments, and interactive parameters.

---

## The 7 Core Product Elements of a MorphSection

```
┌──────────────────────────────────────────────────────────┐
│                   Top Screen Edge                        │
│ ┌──────────────────────────────────────────────────────┐ │
│ │ 📷 Cutout Bridge  [Left Gutter] [Right Gutter]       │ │
│ └──────────────────────────────────────────────────────┘ │
│ ❖ NotchShape (Corner Fillets: topRadius, bottomRadius)    │
│ ⚡ NotchMotion (Spring Engine: stiffness, damping)        │
│ 🎨 NotchStyle (Ink, Shadow)                              │
│ 🎯 NotchPointerMonitor (Transit Filter & Jitter Gate)    │
│ 📐 NotchExpandedTopReserve (Taper-Aware Insets)          │
│ 📊 NotchBars (Zero-CPU CoreAnimation Rendering)          │
└──────────────────────────────────────────────────────────┘
```

### 1. Silhouette & Fillets (`NotchShape`)
* **Mission**: Maintains one morphing shape with concave top corner fillets and convex bottom corner fillets.
* **Arguments & Parameters**:
  * `topCornerRadius: CGFloat`: Concave top radius curling into the screen bezel (~6pt when collapsed, ~22pt when expanded; 0 in both on displays with no cutout).
  * `bottomCornerRadius: CGFloat`: Convex bottom radius (~19pt when collapsed, ~22pt when expanded).
  * `width: CGFloat` & `height: CGFloat`: Morphing dimensions.
* **Key Invariant**: Interpolating 4 numbers on a single shape eliminates cross-fade cuts, producing a genuine physical morph.

### 2. Cutout Hardware Bridge (`NotchCutoutLayout`)
* **Mission**: Shields hardware camera cutout and provides leading & trailing gutters for content.
* **Arguments & Parameters**:
  * `cutoutWidth: CGFloat`: Width of physical camera housing (derived via `NSScreen+Notch`).
  * `gutterWidth: CGFloat`: Usable width on each side of the cutout.
  * `pillHeight: CGFloat`: Height of the resting pill.

### 3. Motion Spring Engine (`NotchMotion`)
* **Mission**: Single-driver spring choreography for shape morphing and content reveal timing.
* **Arguments & Parameters**:
  * `expand: Animation`: Spring curve (`stiffness: 190`, `damping: 22`).
  * `collapse: Animation`: Monotonic ease (`smooth(0.30)`).
  * `contentRevealDelay: TimeInterval`: Head start (~0.08s - 0.12s) given to shape before fading in text.

### 4. Ink & Shadow Style (`NotchStyle`)
* **Mission**: Pitch-black hardware blending vs warm paper translucent surface ink.
* **Arguments & Parameters**:
  * `ink: Color`: Pure black (`#000000`) for hardware cutout fusion, or warm paper (`#0D0D0F`).
  * `shadowColor` / `shadowRadius` / `shadowOffsetY`: Drawn as two derived passes — a tight `contactShadow` that grounds the panel and a wide `ambientShadow` that fades out. Suppressed while collapsed.
  * `shadowReachHorizontal` / `shadowReachBelow`: How far the falloff actually runs (`2 × radius`, plus the offset downward). The window reserves at least this, so a wide shadow grows the window instead of being clipped.
  * No stroked edge in either phase — a rim would outline the silhouette against the desktop and trace the cutout. Ink and shadow only.

### 5. Pointer Hysteresis & Hit Testing (`NotchPointerMonitor`)
* **Mission**: Dual-delay pointer gate filtering cursor transits and edge jitter.
* **Arguments & Parameters**:
  * `hoverOpenDelay: TimeInterval` (~0.15s): Filters fast cursor transits to menu bar.
  * `hoverCancelGrace: TimeInterval` (~0.10s): Absorbs boundary tremor at cutout edge.
  * `interactiveRect: CGRect`: Limits hit-testing strictly to drawn ink.

### 6. Top Reserve & Content Insets (`NotchExpandedTopReserve`)
* **Mission**: Clears hardware cutout and calculates taper-aware content insets.
* **Arguments & Parameters**:
  * `topReserve: Policy`: `.cutoutOnly`, `.always`, `.fixed(_:)`, or `.none`.
  * `expandedContentInsets`: Insets derived from corner radii to clear inward side-wall tapers.

### 7. Activity Bars & Continuous Motion (`NotchBars`)
* **Mission**: Continuous equalizer indicator rendering with zero main-thread CPU cost.
* **Arguments & Parameters**:
  * `barCount: Int`, `height: CGFloat`, `period: Double`, `stagger: Double`.
  * Offloaded directly to `CAShapeLayer` on the render server.

---

## Interactive Inspection

### In Swift (`Examples/NotchDemo`)
Run the demo app:
```sh
swift run NotchDemo
```
Select the **Morph Inspector** preset to inspect elements live. Hovering over or tapping an element highlights its region, displays argument definitions, and explains its mission.

### On the Web Documentation
Visit the interactive **MorphSection Inspector** on the website homepage to manipulate live parameter knobs (`topRadius`, `bottomRadius`, `stiffness`, `damping`, `cutoutWidth`, `inkTheme`) in real-time.
