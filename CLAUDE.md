# Working on this project

Native jigsaw puzzle for macOS / iPadOS / iOS. Swift 6, SwiftUI, no dependencies,
fully offline. Read this before changing anything — it records the decisions and
the traps that are expensive to rediscover.

## Build and test

```bash
xcodebuild -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzle \
  -destination 'platform=macOS,arch=arm64' -configuration Debug test
```

Swap the destination for `platform=iOS Simulator,name=iPhone 17 Pro` or
`name=iPad Pro 13-inch (M5)`. **53 tests in 6 suites must pass** before any change
is called done. Grep the output for `^✔ Test run` — xcodebuild buries it in noise.

The product is named `Sasha's Pazzle.app` (`PRODUCT_NAME`), but the Swift module
and every import stay `JigsawPuzzle` (`PRODUCT_MODULE_NAME`). Do not "fix" that
mismatch — it is deliberate.

## Where things live

| Path | Role |
|---|---|
| `Sources/Engine/` | `EdgeProfile`, `PuzzleGeometry`, `PuzzleState` — pure, `Sendable`, no SwiftUI |
| `Sources/Art/` | Procedural picture generators (29 families × 20 seeds = 580) |
| `Sources/Render/` | `PieceTextureStore` — parallel bitmap cutting with the bevel |
| `Sources/Interaction/` | `Viewport`, `BoardEventView` (AppKit/UIKit input bridge) |
| `Sources/Game/` | `GameSession` plus the playing screen |
| `Sources/Library/` | Image pipeline, caches, photo import, home screen |

`Engine/` and `Art/` know nothing about SwiftUI. Keep it that way — that is what
makes them unit-testable and safe to run off the main thread.

## Invariants — breaking these breaks the game

- **Neighbouring pieces share one identical curve.** Every interior cut is stored
  once; a piece's outline reuses it, reversed where the clockwise walk runs
  against the canonical direction. `GeometryTests` asserts equality at `1e-9`.
  Never generate a piece's edges independently.
- **Two pieces are joined iff their groups share a translation.** Snapping,
  merging and completion all fall out of this. Do not add per-edge connection
  bookkeeping.
- **Board units are resolution independent** — board area is always
  `PuzzleGeometry.referenceArea`. Window size, zoom and orientation only change
  `Viewport`. If a resize ever loses pieces, something wrote screen units into
  the model.
- **Geometry regenerates from `(seed, columns, rows)`.** Saves must never store
  control points.
- **Every artwork ends with `ArtToolkit.detailPass`.** Without high-frequency
  texture an 800-piece puzzle is unsolvable; a test enforces it.

## Traps already paid for

**macOS window.** With `GENERATE_INFOPLIST_FILE`, the app needs
`INFOPLIST_KEY_NSPrincipalClass[sdk=macosx*] = NSApplication` or **no window is
ever created**. Also: launch through `open`, never the executable directly — a
binary started straight from a shell gets no window.

**Coordinate systems.** Board space is y-**down**; `CGContext` is y-**up**. Use
`drawFlipped` for images. A piece path drawn without the flip comes out mirrored
(this shipped a flat-top piece upside down once).

**`@ToolbarContentBuilder` conditionals silently produce nothing** on a compact
width. Branch inside the `ViewBuilder`, not at toolbar-content level.

**`.frame(minWidth:)` is a window constraint.** Applying it on iOS forces the
layout wider than the phone screen and pushes the HUD and toolbar off both edges.
Guard it with `#if os(macOS)`.

**Tests must inject a temp `SaveStore`**, otherwise they write into the player's
real saved games. `GameSession.init(..., saveStore:)` exists for this.

**Core Image disappointments.** `CIKMeans` + `CIPalettize` produced unusable mush
and `CIEdges` was too weak to survive a multiply blend. The icon pipeline uses a
hand-rolled k-means quantiser and a thresholded Sobel instead. Do not "simplify"
it back. Never `CIColorPosterize` with a saturation boost — it shreds hue.

**Hoist `PerlinNoise` out of per-pixel closures.** One construction per pixel
made artwork generation 50× slower; it allocates a 512-entry table.

**Piece textures crop the source**, they do not draw the whole image under a
clip. Cropping a `CGImage` is free; drawing is not.

## Verifying visually

There is no way to read back a live SwiftUI window — `cacheDisplay` and
`CALayer.render` both return blank. Two working routes:

- **`DebugStageDriver`** (debug builds only) drives the app into a named state at
  launch: `open -n "<app>" --args --stage huge --clear-saves`. Stages: `library`,
  `dark`, `settings`, `setup`, `board`, `scattered`, `snapped`, `hint`,
  `completed`, `huge`, `hugeSolved`.
- **Screenshots**: on macOS capture the window only (find its number via
  `CGWindowListCopyWindowInfo`, then `screencapture -o -l <id>`) — a full-screen
  grab exposes the user's desktop. On iOS use `xcrun simctl io <device> screenshot`.

Never publish a screenshot containing the user's own photos or saved games; the
GitHub repository is public.

## Device installs

Free Apple ID: builds expire after **7 days**, at most 10 App IDs can be created
per 7 days (and they cannot be deleted — renaming the bundle burns them fast),
and the iPad needs **Developer Mode** enabled in Settings → Privacy & Security.
