# Hover animation

The initial approximation used a screen recording. Subsequent static analysis
of the supplied Apple Dock executable established the spatial warp and finite
entry/exit easing described in [the analysis notes](apple-dock-analysis.md).

## Geometry

- Sine-warp both edges of each tile; their difference determines its size.
- Use a radius of three base tile widths and normalize the warp so a centered
  tile reaches the configured magnification exactly.
- Transform spacing alongside icons, rather than retaining fixed gaps between
  individually scaled icons.
- Track the pointer directly, without an added tracking spring.
- Anchor expansion around the pointer; apply screen-boundary corrections and
  scrolling support where the Quickshell panel constrains the row.
- Keep the display-side icon baseline and running indicators stable.

## Entry and exit

The magnification amount uses a half-cosine interpolation over a finite duration:

```text
duration_ms = floor(1 + 42 ln(1 + |sizeChange| / 2))
progress = 0.5 - 0.5 cos(π clamp(elapsed / duration, 0, 1))
```

Reversing an unfinished transition starts from its current value. The duration
adapts to the remaining size change. Animation ends exactly at the target and
does not depend on the display refresh rate.

Hover begins on the visible glass, not its empty layer-surface margin. Once
expanded, the enlarged icons remain inside the hover region. On exit the wave
retains its last pointer position while contracting. These hit-region choices
remain adaptations, rather than recovered Apple constants.

Hover labels appear after 180 ms on first entry and switch immediately between
icons. Live previews replace labels after their preview delay. Label timing
and preview behavior are project-specific.

Tests cover the recovered formulas, pointer alignment, slot ordering, screen
constraints, entry/exit, stationary hover, labels, vertical placement, and drag
reordering.
