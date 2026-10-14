# Apple Dock magnification analysis

Static inspection of a locally supplied Dock.app informed the magnification
model. These notes describe mathematical behavior, not a complete reproduction
of Apple's Dock. No Apple executable, disassembly, or artwork is included here.

## Inspected build and method

- Bundle version: `2571.0.6.402`, short version `1.8`.
- Bundle declares macOS 27.0 as its minimum system version.
- Architecture inspected: arm64e, extracted from the universal executable.
- Extracted slice SHA-256:
  `8aacf1a8f961f10e0e67e1949b98c21f6f06a396e95cb5f443a75c2dcafe602e`.
- Tools: LLVM 21 Mach-O disassembly, Python `struct`/`plistlib`, and a local
  Objective-C metadata reader. LLVM could not resolve this image's chained
  pointer format directly; decoding its internal rebase pointers recovered
  class names, method implementations, selector stubs, and ivar offsets.

The addresses below are unslid virtual addresses in that specific slice.

## Confirmed spatial behavior

`DockBar.fSize` at `0x10025337c` returns **3**. The magnification setup near
`0x100011cb4` multiplies this by `tileSize` to obtain `fishSize`.

For base tile width `s`, enlarged width `L`, current magnification amount `m`,
and pointer center `c`, the setup and edge-transform arithmetic yield:

```text
R = 3s
A = m (L - s) / (2 sin(πs / (4R)))
warp(x) = x + A sin((π/2) clamp((x - c) / R, -1, 1))
```

The normalization is visible around `0x100011ce4–0x100011d50`. Repeated edge
transforms around `0x100011eac–0x100012094` clamp outside the radius and use
`sinf` inside it. Tile width comes from the difference between transformed
edges. A centered base tile therefore reaches exactly `L` at full magnification.
The literal used for π is `3.1415927410125732` in this build.

The normal pointer path around `0x100011c54–0x100011c84` reads
`lastCapturedMousePosition`, clamps it to `barLeft`/`barRight`, and sets
`fishCenter`. That path does not apply a tracking spring. Special cases, such
as an externally selected tile, have separate handling.

## Confirmed transition behavior

`DockBar.fishSpeed` at `0x100253370` returns **42**. `startFishing` and
`stopFishing` enter the common routine at `0x10005f1bc`. For the normal
non-dragging path, it computes:

```text
duration_ms = floor(1 + 42 ln(1 + |targetSize - currentSize| / 2))
```

`currentSize` here is `tileSize + currentFish`. The transition targets the
normalized `fish` amount of 1 on entry and 0 on exit. For a 48-unit size
change, duration is **136 ms**. The dragging branch instead uses `moveSpeed`
(270 in this build); this does not establish the behavior of every drag mode.

The `fish` property is allocated with easing mode 1 at `0x10025889c` and stored
through the ivar offset resolving to `0x160`. Its updater at `0x1000502e0`
clamps elapsed time, uses cosine easing, and then interpolates:

```text
t = clamp(elapsed / duration, 0, 1)
value = from + (to - from) (0.5 - 0.5 cos(πt))
```

Thus hover expansion is a finite easing transition, not the critically damped
spring previously inferred from the screen recording.

## Adaptation in this project

`DockModel.js` implements the equations independently. Our slot width supplies
the base tile metric, while artwork remains inset within its slot. The waveform
therefore expands icon spacing along with icon size. Pointer tracking is direct,
and entry/exit uses the size-dependent finite transition.

Quickshell rendering, screen-edge constraints, scrolling, icon artwork, hover
hit regions, labels, and window previews remain project-specific. We have not
executed Apple's Dock under macOS or verified every branch. These findings
improve the mathematical match without establishing pixel-identical behavior.
