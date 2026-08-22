# Jigsaw Puzzle

A native Apple jigsaw puzzle for **macOS, iPadOS and iOS**, written in Swift 6 and
SwiftUI. Real interlocking piece geometry, real drag-and-drop, real groups —
from a 12-piece warm-up to an 800-piece project. No web view, no backend, no
network access of any kind.

<p align="center">
  <em>580 built-in pictures · 12 – 1000 pieces · works entirely offline</em>
</p>

---

## Requirements

| | |
|---|---|
| Xcode | 16.0 or newer (developed on **Xcode 26.6**) |
| Swift | 6.0 language mode (toolchain **Swift 6.3**) |
| macOS | 15.0 or newer |
| iOS / iPadOS | 18.0 or newer |
| Architecture | Apple Silicon and Intel |
| Dependencies | **none** — no SPM packages, no CocoaPods, no Carthage |

## Running it

```bash
open JigsawPuzzle.xcodeproj
```

Pick the **JigsawPuzzle** scheme, choose *My Mac* (or a simulator) and press ⌘R.

From the command line:

```bash
xcodebuild -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzle -destination 'platform=macOS,arch=arm64' build
```

```bash
xcodebuild -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzle -destination 'platform=macOS,arch=arm64' test
```

```bash
xcodebuild -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzle -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test
```

### Installing on a physical iPhone or iPad

The project deliberately ships **no signing credentials**. To run on your own
device:

1. Open the project in Xcode.
2. Select the **JigsawPuzzle** target → *Signing & Capabilities*.
3. Set **Team** to your Apple ID / Apple Developer team.
4. Change **Bundle Identifier** from `com.example.JigsawPuzzle` to something
   unique to you, e.g. `com.yourname.JigsawPuzzle`.
5. Select your device and press ⌘R. On the device, trust the developer
   certificate under *Settings → General → VPN & Device Management*.

The macOS build is signed ad-hoc (`Sign to Run Locally`) and needs no team.

---

## The puzzle engine

### Shared edges

The heart of the app is that **every interior cut exists exactly once**:

```
horizontalCuts[row * columns + column]   // between (row, col) and (row+1, col)
verticalCuts[row * (columns-1) + column] // between (row, col) and (row, col+1)
```

A piece's outline reuses those very curves, reversing the two it walks
backwards. `EdgeCurve.reversed` mirrors control points within each cubic segment
and flips the chain order, which is an *exact* operation — so

```
A.right ≡ inverse(B.left)     A.bottom ≡ inverse(C.top)
```

holds by construction rather than by tolerance. There is no matching pass and no
possibility of drift, gaps or overlaps. `GeometryTests` asserts it for every
neighbouring pair, sample by sample, at 1e-9.

### Edge shape

Each cut is a five-segment cubic Bézier profile defined in a normalised frame
from `(0,0)` to `(1,0)`:

```
               ___
              /   \      head  (half-width b, apex ≈ 1.03·h)
             |     |
  ___________\     /__________   neck  (half-width w < b → undercut)
  ^ baseline, gently bowed
```

Randomised per edge — position, neck and head width, height, skew, baseline bow —
from a seed derived by hashing `(puzzleSeed, kind, row, column)`. Tabs are sized
from the *smaller* cell dimension so they stay in proportion on any grid. Tests
check the outlines are closed, tab-bearing on interior edges, perfectly flat on
the border, and free of self-intersections.

### Board units

The engine works in **board units**, a space whose area is always 1 000 000
(1000 × 1000 for a square picture). Window size, zoom and orientation never touch
these numbers — they only change the `Viewport` transform. Resizing a window or
rotating a device is a pure re-layout: nothing is recomputed, nothing is lost.

### Groups

A connected cluster is described by a **single translation**, since its members
are by definition in their exact solved relationship. That yields one crisp
invariant:

> two pieces are correctly joined **iff their groups share the same translation**

Everything falls out of it. Snapping = find the nearest candidate translation
(a touching group's, or `.zero` for the board itself) within tolerance. Merging =
breadth-first absorption of every touching group that now matches, so a piece
dropped into a hole joins all four neighbours at once. Moving a group is O(1) and
can never split it. Completion = one group left.

Snap tolerance scales with both piece size and zoom, and is clamped below half a
cell so a piece can never grab the wrong slot.

---

## Performance

An 800-piece board is the design target, not an afterthought.

| Stage | Release | Debug (`-Onone`) |
|---|---|---|
| Generate a 2800 px picture | 0.20 s | 0.41 s |
| Build 35 × 23 geometry | < 0.01 s | < 0.01 s |
| Cut 805 piece bitmaps | 0.05 s | 0.05 s |

Measured on an Apple Silicon Mac. What makes it work:

* **Pre-rendered piece bitmaps.** Clipping 800 Bézier outlines against a
  photograph every frame is hopeless; doing it once per piece and blitting the
  cached bitmap turns the draw loop into textured rectangles. Cutting is spread
  across all cores and chunked so it reports progress and can be cancelled.
* **Cropped source fragments.** Each piece draws a `CGImage.cropping` view of the
  source rather than the whole picture under a clip — cropping is free, drawing
  is not.
* **A texture budget.** `PieceTextureStore.affordableScale` lowers the pixel
  scale rather than risking a memory-pressure termination, and re-cuts only when
  zoom changes by more than 25 %, debounced.
* **Culling and a cached draw order.** Off-screen pieces are skipped; the
  back-to-front order is recomputed only when the *structure* changes, never
  during a drag.
* **Downsampled decoding.** Imported photos are never fully materialised — the
  longest edge is capped at 4096 px on import and decoded through ImageIO
  thumbnails thereafter.
* **Noise at a fraction of output resolution.** Procedural artwork samples its
  noise fields at ≤ 560 px and upsamples; the permutation table is a raw buffer
  so the innermost loop stays fast even in an unoptimised build.

---

## The picture library

Shipping several hundred photographs is neither practical nor licensable for an
offline app, so the built-in library is **generated on the device**: 29 generator
families × 20 seeded variants = **580 unique, reproducible pictures**, covering
space, mountains, nature, sea, city, animals and abstract work.

Every artwork ends with a mandatory detail pass — structured, multi-scale texture
rather than smooth gradients — because an 800-piece puzzle is only solvable if
neighbouring pieces look different. A test asserts that no family produces a
picture with too many flat regions.

Pictures are produced lazily at the size actually needed and cached in memory
(LRU) and on disk, so opening one twice is a decode rather than a render.

**Your own photos** are imported through `PhotosPicker` (multi-select) or from
Files, copied as optimised JPEGs into the app container, indexed by a small JSON
manifest, and can be renamed or deleted. Copies rather than references, so a
puzzle keeps working after the original leaves your library.

---

## Persistence

* **Saved games** — one JSON document, written atomically, holding the picture
  reference, difficulty, elapsed time, every group and its translation, and the
  completion flag. Geometry is *not* stored: `seed`, `columns` and `rows`
  regenerate the identical Bézier cut, which keeps an 800-piece save small.
* **Autosave** — debounced two seconds after any change, plus immediately on
  pause, on leaving the foreground and on closing the board.
* **Photo library** — a JSON manifest next to a folder of JPEGs, both inside the
  app container. Entries whose file has vanished are dropped on load.

Nothing leaves the device. There is no account, no server and no analytics.

---

## Architecture

```
Sources/
├── App/          JigsawPuzzleApp, AppModel, RootView, menu commands
├── Model/        Difficulty, PuzzleAspect, LibraryItem, categories
├── Engine/       EdgeProfile · PuzzleGeometry · PuzzleState   ← pure, testable, Sendable
├── Render/       PieceTextureStore (parallel bitmap cutting + bevel)
├── Interaction/  Viewport, BoardEventView (AppKit/UIKit input bridge)
├── Art/          Noise, Palette, ArtToolkit, ArtFamily, ArtRenderer
├── Library/      ImagePipeline, ImageStore, PhotoLibraryStore, HomeView
├── Game/         GameSession, BoardView, TrayView, SetupView, overlays
├── Settings/     AppSettings, SettingsView
├── Persistence/  GameSnapshot, SaveStore
├── Support/      SplitMix64, CoreGraphics helpers, Feedback, debug driver
└── Resources/    Assets.xcassets, Localizable.xcstrings
Tests/            51 tests across 5 suites
```

The engine layer (`Engine/`, `Art/`) is `nonisolated` and `Sendable` and knows
nothing about SwiftUI, which is what lets it be unit-tested directly and rendered
on background threads. The project uses Swift 6 strict concurrency with
`MainActor` default isolation.

### Input

Drawing is declarative (a single SwiftUI `Canvas`); **input is native**. A thin
`NSView` / `UIView` sits over the board and provides an unambiguous gesture
contract:

| | |
|---|---|
| Mac | drag a piece with the mouse; drag empty table to pan; scroll to pan; ⌘-scroll or trackpad pinch to zoom; right-click a piece to return it to the tray |
| iPad / iPhone | one finger (or Apple Pencil) moves a piece, or pans when it starts on empty table; two fingers pan; pinch zooms |

Overlapping SwiftUI gestures were rejected in favour of real gesture recognisers
because stability of the core mechanic matters more than uniformity.

### Layout

| | |
|---|---|
| Mac | board fills the window, piece tray docked on the trailing edge |
| iPad landscape | board left, tray right |
| iPad portrait / iPhone | board on top, tray along the bottom |

The layout follows the window's shape, so Split View, Stage Manager and window
resizing are handled by the same code path as rotation.

---

## Features

- 580 built-in pictures + your own photos (Photos and Files import)
- Difficulty from 12 to 800 pieces, plus a custom slider up to 1000
- Framing: original, 1:1, 3:2, 4:3, 16:9, 2:3 — centre-cropped, never stretched
- True jigsaw geometry with tabs, sockets and flat borders
- Snap, green connection flash, group forming and group merging
- Pan and zoom with fit-board / fit-table shortcuts
- Elapsed-time clock that stops on pause and in the background
- Pause, hint, show original, scatter-all, undo / redo
- Autosave and *Continue* from the library
- Settings: theme, sound, haptics, picture guide, piece outlines, snap assist,
  defaults, reset saves
- Procedurally synthesised sound and haptics for snap, merge and completion
- Full keyboard-shortcut menu bar on macOS
- English and Russian, Dynamic Type, VoiceOver labels, light and dark

## Tests

`Tests/` contains **53 tests in 6 suites** (Swift Testing), covering the areas the
engine cannot be allowed to get wrong:

grid selection · edge generation · edge matching between neighbours · flat
borders · closed, non-self-intersecting outlines · determinism from a seed ·
coordinates · snap calculation and tolerance scaling · group merge · four-way
bridging · group movement · completion detection · shuffle · scatter · the real
clock · undo/redo · save/load and serialisation · image crop, resize and decode ·
artwork determinism and local contrast · texture rendering and the memory budget ·
photo import, reload and deletion.

```bash
xcodebuild -project JigsawPuzzle.xcodeproj -scheme JigsawPuzzle \
  -destination 'platform=macOS,arch=arm64' test
```

### Visual verification

`DebugStageDriver` (debug builds only) drives the app into a named state at
launch so screens can be photographed reproducibly:

```bash
open -n /path/to/JigsawPuzzle.app --args --stage huge --clear-saves
```

Stages: `library`, `dark`, `settings`, `setup`, `board`, `scattered`, `snapped`,
`hint`, `completed`, `huge`, `hugeSolved`.

## Known limitations

- Built-in pictures are **generated artwork, not photographs**. Bundling 500+
  real photos is not possible for an offline, dependency-free, licence-clean
  app; import your own for photographic puzzles.
- Pieces cannot be rotated. Every difficulty assumes the classic
  upright-pieces rule.
- Above roughly 1000 pieces the tray becomes an impractical way to play; use
  *Scatter Pieces*. The engine itself has no hard limit.
- At very high zoom the piece bitmaps are re-cut on a debounce, so there is a
  brief moment of softness while the sharper set is produced.
- Verified on macOS and in the iPhone/iPad simulators. **No physical iPhone or
  iPad was available**, so on-device behaviour — including Apple Pencil — is
  untested on real hardware.
- Sound is synthesised additively at launch; if the audio engine fails to start
  the app runs silently rather than reporting an error.

## Licence

Sample project — no warranty. The bundle identifier `com.example.JigsawPuzzle` is
a placeholder; replace it with your own before distributing.
