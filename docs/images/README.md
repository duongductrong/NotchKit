# Images

| File | Used by | Notes |
|---|---|---|
| `hero.svg` | Top of the root `README.md` | Vector banner. Silhouettes are drawn with the real `NotchShape` construction, so it stays accurate if the shape changes. |
| `demo.gif` | Root `README.md`, "See it" section | **Not committed yet.** Drop a screen recording here and the README will pick it up. |

## Recording `demo.gif`

A short loop of the morph is worth more than any static image, because the whole
point of the library is motion:

1. `swift run NotchDemo`
2. Record the notch area only — `Cmd-Shift-5`, "Record Selected Portion". Keep the
   crop tight; a full-screen capture makes the island unreadably small.
3. Show hover-open, then click-outside-to-dismiss. Two or three seconds is plenty.
4. Convert, keeping it small enough that GitHub will inline it:
   ```sh
   ffmpeg -i recording.mov -vf "fps=30,scale=760:-1:flags=lanczos" -loop 0 demo.gif
   ```
5. Aim for under ~5 MB. If it is larger, drop to `fps=24` or `scale=640`.

Record on a MacBook with a real notch if you can — merging with the physical
cutout is the effect that sells it, and an external display cannot show it.
