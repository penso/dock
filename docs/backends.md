# Compositor backends

The shared shell does not import `Quickshell.Hyprland`. A Loader selects one
backend from `qml/backends/`. `DOCK_COMPOSITOR=auto` selects Hyprland when
`HYPRLAND_INSTANCE_SIGNATURE` is present, otherwise generic Wayland. Auto mode
falls back to Wayland if the optional Hyprland module cannot load.

Explicit selection:

```sh
DOCK_COMPOSITOR=wayland ./bin/dock
DOCK_COMPOSITOR=hyprland ./bin/dock
```

## Shared interface

Backends expose:

- `name`, `capabilities`, `focusedScreen`, and `activeWorkspace`.
- A reactive `windows` array containing `appId`, `title`, `wayland`,
  `activated`, `minimized`, `urgent`, and `workspaceId`.
- `activate(window)`, `close(window)`, `minimizeActive()`, and `restore()`.
- `monitorFor(screen)`, `workspaceFor(monitor)`, `topMargin(monitor)`, and
  `overlaps(workspace, rectangle)` for panel placement and optional intelligent hiding.

Window records retain the native Quickshell toplevel handle, rather than
inventing compositor-independent numeric window IDs. The UI can activate and
close them without passing through a shell command.

## Generic Wayland

`WaylandBackend.qml` uses `Quickshell.Wayland.ToplevelManager`, backed by
`zwlr_foreign_toplevel_manager_v1`. Panels use `zwlr_layer_shell_v1`.
It never starts `hyprctl` or imports the Hyprland QML module.

The protocol exposes window titles, app IDs, activation, minimization, maximization,
and fullscreen state. It does **not** expose workspace IDs, window rectangles,
or urgency. Those capabilities are disabled rather than guessed. App-provided
Unity Launcher badges, progress, and urgency remain available independently.

Minimization and activation are requests the compositor can ignore. Some
compositors, including Sway, do not implement a conventional minimized state.
Quickshell 0.3.2 also needs to have received input before its native activation
method has a last-used seat; normal icon clicks provide that input. An IPC
activation request made immediately after startup, before any dock interaction,
may therefore do nothing.

Per-window screenshots require another capture protocol; otherwise previews
use application icons. No claim of universal Wayland support is made: GNOME
needs a Shell extension, while Plasma needs a native window-management adapter.
An X11 backend would additionally require an X11-capable panel implementation.

## Hyprland

`HyprlandBackend.qml` preserves workspace-aware switching, special-workspace
minimization/restoration, urgency events, and client-rectangle overlap checks.
It uses `dockctl` for window dispatchers. `DOCK_BACKEND=lua|classic` selects
the Hyprland command syntax independently of `DOCK_COMPOSITOR`.

## Validation

Both backends were exercised in a running Hyprland session using a temporary
application: discovery, activation, and native close all passed. For generic
mode, `DOCK_HYPRCTL` pointed to a failing sentinel executable; it was never
called. Native activation was tested after pointer interaction with the panel.
Separate launcher tests cover automatic selection, explicit overrides, and
portable minimize/restore command routing.

Other compositors are protocol-compatible candidates, not yet runtime-verified
targets. This distinction is reflected in the README.
