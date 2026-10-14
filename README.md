# Penso Dock

A macOS-inspired dock and application launcher for **Hyprland**, built with
[Quickshell](https://quickshell.org/), Qt Quick, and a small Python helper.

## Features

- Smooth, spring-driven icon magnification and launch animation.
- Drag to reorder favorites or pin a running application.
- Running-window indicators, window switching, and live hover previews.
- Restore minimized windows and close windows from their preview cards.
- Bottom, top, left, and right placement, with multi-monitor panels.
- Auto-hide and intelligent hiding when windows overlap the dock.
- Searchable application grid with keyboard navigation.
- Live settings for icon size and magnification; editable theme colors.

The standalone dock appears on normal workspaces, whether tiled or floating.
It manages its own configuration and does not require Omarchy, Waybar, or the
author's workspace-layout scripts.

## Requirements

- Linux with a running Hyprland Wayland session and `hyprctl` on `PATH`.
- **Quickshell 0.3.2**, built with Hyprland, Wayland, and screencopy support.
  This is the version tested during extraction; older releases are unverified.
- Qt 6 QML modules: QtQuick, QtQuick.Controls, QtQuick.Layouts, QtQuick.Effects.
- Python 3.10+ (standard library only).
- An installed icon theme and applications with desktop files.

The default dispatcher backend uses Hyprland's Lua API, tested on the
0.56.0 development build. For versions using traditional dispatchers, launch
with `PENSO_DOCK_BACKEND=classic`; that backend has unit coverage but has not
been tested against an older running compositor.

Install Quickshell and its QML dependencies using your distribution's packages
or the [upstream installation instructions](https://quickshell.org/docs/guide/install-setup/).
Package names vary by distribution.

## Run from a checkout

```sh
./bin/penso-dock
# Traditional Hyprland dispatcher API:
PENSO_DOCK_BACKEND=classic ./bin/penso-dock
```

Settings are created at `${XDG_CONFIG_HOME:-~/.config}/penso-dock/` on first run.
Right-click the launcher icon for settings, edge placement, and hide options.
Right-click an app to pin/unpin it; drag icons to change their order.

## Install for your user

```sh
python3 install.py
~/.local/bin/penso-dock
```

The installer copies source files into `${XDG_DATA_HOME:-~/.local/share}/penso-dock`,
installs a launcher into `~/.local/bin`, and writes a systemd user service.
Existing dock settings and theme colors are preserved. Re-run to update.
An existing `penso-dock.service` is replaced; stop a personal version before
switching to this package so two docks do not overlap.

### Autostart

Use **one** of these methods:

Traditional Hyprland configuration:

```ini
exec-once = ~/.local/bin/penso-dock
```

Lua Hyprland configuration:

```lua
hl.on("hyprland.start", function()
  hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/penso-dock")
end)
```

Or, for systemd-managed desktop sessions, import the session environment and
start the service from your session startup:

```sh
systemctl --user daemon-reload
dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE PATH
systemctl --user start penso-dock.service
```

When using a custom XDG directory or dispatcher backend, also import
`XDG_CONFIG_HOME`, `XDG_DATA_HOME`, and `PENSO_DOCK_BACKEND` if set.

## Configuration and commands

See [`config/settings.json`](config/settings.json) and
[`config/theme.json`](config/theme.json) for defaults. Files are watched live.
Pin IDs are desktop file names without the `.desktop` suffix. Missing apps are
kept in settings but not displayed until installed.

```sh
penso-dock ctl pin org.gnome.Nautilus
penso-dock ctl position left
penso-dock ctl appearance 48 150
penso-dock ctl autohide on
penso-dock ctl intellihide off
penso-dock ipc apps
penso-dock ipc settings
penso-dock ipc status
```

Minimization parks windows in `special:minimized`, since Hyprland does not have
a conventional minimized state. Bind `penso-dock ctl minimize` to your preferred
shortcut or titlebar action; the dock restores those windows on activation.

| Environment variable | Default / purpose |
| --- | --- |
| `PENSO_DOCK_CONFIG_DIR` | `$XDG_CONFIG_HOME/penso-dock`; isolate a test configuration |
| `PENSO_DOCK_HYPRCTL` | `hyprctl`; custom executable path |
| `PENSO_DOCK_QUICKSHELL` | `quickshell`; custom executable path |
| `PENSO_DOCK_BACKEND` | `lua` or `classic` window dispatchers |

## Development and tests

```sh
node --test qml/tests/model.test.js
python3 -m unittest discover -s tests -v
QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software \
  /usr/lib/qt6/bin/qmltestrunner -input qml/tests -o -,txt
```

QML tests require QtTest and `qmltestrunner` (its location varies by distribution).
They exercise hover magnification, drag ordering, activation, edge placement,
size changes, and launch feedback. Python tests exercise settings and window
actions without touching a real desktop. Node tests cover the motion model.

To try source changes alongside a separate settings directory:

```sh
PENSO_DOCK_CONFIG_DIR=/tmp/penso-dock-dev ./bin/penso-dock
```

`qml/` contains the UI; `bin/penso-dockctl` handles settings and dispatchers;
`bin/penso-dock` launches the same code from a checkout or user installation.
No compiled binaries, personal app list, or machine-specific paths are shipped.

## License

MIT. See [LICENSE](LICENSE).
