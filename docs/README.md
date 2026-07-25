# NotchKit documentation

| Guide | Read it when |
|---|---|
| [Getting started](getting-started.md) | Installing, building a first island, verifying it on real hardware. |
| [Customization](customization.md) | Changing sizes, colours, motion, content slots, silhouettes, indicators. |
| [Architecture](architecture.md) | Before modifying NotchKit itself, or when something janks and you need to know why. |
| [Motion](motion.md) | Tuning curves, or designing a motion set from scratch. |
| [Recipes](recipes.md) | Notification islands, progress, media controllers, multi-display, hotkeys. |
| [Troubleshooting](troubleshooting.md) | Anything is wrong. ~45 symptom → cause → fix entries. |

## The short version

An island is a fixed-size, mostly-transparent `NSPanel` pinned to the top of the
screen, containing **one** SwiftUI shape that morphs between a pill and a panel.

Four rules carry most of the weight:

1. **The window never resizes.** Animating a window frame while SwiftUI animates its
   contents puts two animators on one visual, and they cannot stay in phase.
2. **One shape morphs; two views never trade places.** A cross-fade reads as a cut.
3. **Hit test to the drawn ink, not the window**, or a collapsed island swallows every
   click across the top of the screen.
4. **Hover needs two delays** — one to filter pointer transits, one to filter jitter at
   the cutout edge.

Each has a specific bug attached to violating it, which is what
[troubleshooting.md](troubleshooting.md) indexes.

## Reading order

New to the library: [Getting started](getting-started.md) →
[Customization](customization.md).

Modifying the library: [Architecture](architecture.md) first. The layer split is what
keeps the motion smooth, and most bugs are one layer doing another layer's job.
