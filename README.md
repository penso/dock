# Dock

A macOS-inspired dock for **Wayland desktops**, built with
[Quickshell](https://quickshell.org/), Qt Quick, and Python.

![Bottom-positioned Dock with smooth icon magnification](docs/screenshots/dock.png)

## Features

- Sine-warp icon magnification, smooth hover transitions, and launch animation.
- Drag to reorder favorites or pin running applications.
- Drag the divider to resize live; unpinned running apps appear after it.
- Running-window indicators, window switching, and live hover previews.
- App-provided unread badges, progress bars, and urgent-window attention marks.
- Restore minimized windows and close windows from preview cards.
- All four screen edges, multi-monitor panels, auto-hide, and Hyprland intelligent hiding.
- Searchable application grid with keyboard navigation.
- Live icon-size and magnification settings, plus editable theme colors.

![Dock appearance settings with Bottom selected](docs/screenshots/settings.png)

Dock appears on normal workspaces, tiled or floating. It has its own settings
and does not require Omarchy, Waybar, or a particular desktop configuration.
Bottom placement is the default, as shown above.

## Desktop support

Dock uses generic Wayland protocols for window lists and actions. Hyprland is
an optional integration, loaded only when selected or detected.

| Backend | Features |
| --- | --- |
| Generic Wayland | App launch/grid, pins, window switching/closing, native minimize requests, auto-hide, badges, progress |
| Hyprland | All of the above plus workspace-aware switching, overlap hiding, urgent-window events, special-workspace minimization |

The generic backend requires **`zwlr_layer_shell_v1`** and
**`zwlr_foreign_toplevel_manager_v1`**. Compositors such as Sway, labwc, and
Wayfire provide these protocols; actual features depend on their version and
configuration. Minimize requests may be ignored, and live window previews need
an additional supported capture protocol. Generic mode cannot infer window
positions, workspaces, or native urgency from foreign-toplevel alone.

**GNOME, stock KDE Plasma, and X11 are not currently supported targets.** GNOME
would need a Shell extension; Plasma would need its own window-management
adapter. Installation alone cannot add protocols a compositor does not expose.

Both backends have been exercised on Hyprland, including forcing generic mode
with a failing `hyprctl` stub. Other compositors have not yet been runtime-tested.

## Requirements

- Linux and a Wayland compositor exposing the protocols listed above.
- **Quickshell 0.3.2**, built with Wayland/toplevel and screencopy support
  (the tested version; older releases are unverified).
- The Hyprland backend additionally needs Quickshell's Hyprland module and
  `hyprctl` on `PATH`. Screen/window previews need screencopy support.
- Qt 6 QML modules: QtQuick, QtQuick.Controls, QtQuick.Layouts, QtQuick.Effects.
- Python 3.10+ and an icon theme. Core actions use Python's standard library.
- For unread badges and progress: system Python GObject/Gio bindings
  (`python3-gi` on Debian/Ubuntu, `python-gobject` on Arch) and session D-Bus.

The optional Hyprland integration uses its Lua API, tested on a 0.56.0
development build. On Hyprland versions using traditional dispatchers, set
`DOCK_BACKEND=classic`. The classic backend has unit coverage but has not been
tested on an older running compositor.

Install Quickshell through your distribution or follow its
[installation guide](https://quickshell.org/docs/guide/install-setup/).

## Quick start

```sh
git clone https://github.com/penso/dock.git
cd dock
./bin/dock
```

For traditional Hyprland dispatchers:

```sh
DOCK_BACKEND=classic ./bin/dock
```

Backend selection is automatic. To use only generic Wayland protocols, including
on Hyprland:

```sh
DOCK_COMPOSITOR=wayland ./bin/dock
```

Right-click the launcher for settings and hide options. Right-click an app to
pin it; drag icons to reorder them. Settings are created under
`${XDG_CONFIG_HOME:-~/.config}/dock/` on first run.

The divider separates favorites from unpinned running applications. Drag it
**up to enlarge or down to shrink** a bottom dock; size saves when you release.
For other edges, drag toward the desktop to enlarge and toward the edge to
shrink. The handle stays available even when there are no unpinned apps.

## Install

```sh
python3 install.py
~/.local/bin/dock
```

This installs source into `${XDG_DATA_HOME:-~/.local/share}/dock`, a launcher
into `~/.local/bin`, and a systemd user service. Settings and theme colors are
preserved on reinstallation. Stop any other dock before starting this one.

### Autostart

Add `~/.local/bin/dock` to your compositor/session autostart. For example, Sway:

```ini
exec ~/.local/bin/dock
```

Choose one method. Traditional Hyprland configuration:

```ini
exec-once = ~/.local/bin/dock
```

Lua Hyprland configuration:

```lua
hl.on("hyprland.start", function()
  hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/dock")
end)
```

For systemd-managed sessions, run this from your session startup:

```sh
systemctl --user daemon-reload
dbus-update-activation-environment --systemd WAYLAND_DISPLAY PATH
systemctl --user start dock.service
```

Also import `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `DOCK_COMPOSITOR`, and `DOCK_BACKEND` if you set
custom values. For the classic backend, export `DOCK_BACKEND=classic` before
launching, including in your autostart command or service environment.
In a Hyprland session, also import `HYPRLAND_INSTANCE_SIGNATURE` so the service
can select and connect to its optional Hyprland integration.

## Configuration

See [`config/settings.json`](config/settings.json) and
[`config/theme.json`](config/theme.json). Both files are watched live.
Favorites use desktop file names without `.desktop`; missing applications are
retained in settings but hidden until installed.

```sh
dock ctl pin org.gnome.Nautilus
dock ctl position left
dock ctl appearance 48 150
dock ctl autohide on
dock ctl intellihide off
dock ipc apps
dock ipc settings
dock ipc status
```

Bind `dock ipc minimize` to a shortcut or titlebar action. The generic backend
requests native minimization; a compositor may ignore it. Hyprland uses
`special:minimized`, and the dock restores those windows to the current workspace.
Use `dock ipc restore` to restore a minimized window. `dock ipc activate APP_ID`
and `dock ipc closeWindow APP_ID` work through either backend. Address-based
`dock ctl focus/close` commands remain specific to Hyprland.

| Variable | Purpose / default |
| --- | --- |
| `DOCK_CONFIG_DIR` | Settings directory; `$XDG_CONFIG_HOME/dock` |
| `DOCK_COMPOSITOR` | `auto` (default), `hyprland`, or `wayland` |
| `DOCK_HYPRCTL` | Hyprland executable; `hyprctl` |
| `DOCK_QUICKSHELL` | Quickshell executable; `quickshell` |
| `DOCK_BACKEND` | Hyprland window dispatchers; `lua` or `classic` |
| `DOCK_DBUS_PYTHON` | Python with GObject/Gio installed; `/usr/bin/python3` |

### Badges, progress, and attention

Apps supporting the Unity Launcher API can publish unread counts and progress
directly to their dock icon. Counts above 99 display as **99+**. An amber outline
marks attention requested by an app or an urgent Hyprland window.
App-provided badges, progress, and urgency work through both compositor backends.

The app controls its unread count; ordinary notification popups are not counted.
Support depends on the application. Updates are cleared when their sender exits.
Your notification daemon continues to handle popups as usual.

See [badge protocol and testing](docs/badges.md) for details and a live demo.

## Development

```sh
node --test qml/tests/model.test.js
python3 -m unittest discover -s tests -v
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  /usr/lib/qt6/bin/qmltestrunner -input qml/tests -o -,txt
```

QML tests need QtTest and `qmltestrunner`; its path varies by distribution.
Tests cover magnification, drag ordering, window actions, settings persistence,
installation, placement, and launch feedback. Core tests run in GitHub Actions.
See [animation notes](docs/animation.md) and [binary-analysis findings](docs/apple-dock-analysis.md)
for the magnification geometry and timing recovered from a supplied macOS Dock build.

Use `DOCK_CONFIG_DIR=/tmp/dock-dev ./bin/dock` for isolated settings.
`qml/` contains the UI, `bin/dockctl` handles actions, and `bin/dock` launches
the same code from a checkout or installation.
Compositor integration lives in [`qml/backends/`](qml/backends/); see the
[backend contract](docs/backends.md) to add another integration.

Screenshots show the real UI with sample application favorites; desktop content
outside the dock and settings window is excluded.

## License

[MIT](LICENSE).
