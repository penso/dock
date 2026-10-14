# Dock

A macOS-inspired dock for **Hyprland**, built with
[Quickshell](https://quickshell.org/), Qt Quick, and Python.

![Dock with smooth icon magnification](docs/screenshots/dock.png)

## Features

- Spring-driven icon magnification and launch animation.
- Drag to reorder favorites or pin running applications.
- Running-window indicators, window switching, and live hover previews.
- Restore minimized windows and close windows from preview cards.
- All four screen edges, multi-monitor panels, auto-hide, and intelligent hiding.
- Searchable application grid with keyboard navigation.
- Live icon-size and magnification settings, plus editable theme colors.

![Dock appearance settings](docs/screenshots/settings.png)

Dock appears on normal workspaces, tiled or floating. It has its own settings
and does not require Omarchy, Waybar, or a particular desktop configuration.

## Requirements

- Linux, a running Hyprland Wayland session, and `hyprctl` on `PATH`.
- **Quickshell 0.3.2**, built with Hyprland, Wayland, and screencopy support
  (the tested version; older releases are unverified).
- Qt 6 QML modules: QtQuick, QtQuick.Controls, QtQuick.Layouts, QtQuick.Effects.
- Python 3.10+ and an icon theme. No third-party Python packages are needed.

The default window-action backend uses Hyprland's Lua API, tested on a 0.56.0
development build. On versions using traditional dispatchers, set
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

Right-click the launcher for settings and hide options. Right-click an app to
pin it; drag icons to reorder them. Settings are created under
`${XDG_CONFIG_HOME:-~/.config}/dock/` on first run.

## Install

```sh
python3 install.py
~/.local/bin/dock
```

This installs source into `${XDG_DATA_HOME:-~/.local/share}/dock`, a launcher
into `~/.local/bin`, and a systemd user service. Settings and theme colors are
preserved on reinstallation. Stop any other dock before starting this one.

### Autostart

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
dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY HYPRLAND_INSTANCE_SIGNATURE PATH
systemctl --user start dock.service
```

Also import `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, and `DOCK_BACKEND` if you set
custom values. For the classic backend, export `DOCK_BACKEND=classic` before
launching, including in your autostart command or service environment.

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

Bind `dock ctl minimize` to a shortcut or titlebar action to move a window to
`special:minimized`. Clicking its dock entry restores it to the current
workspace. Hyprland does not have a conventional minimized state.

| Variable | Purpose / default |
| --- | --- |
| `DOCK_CONFIG_DIR` | Settings directory; `$XDG_CONFIG_HOME/dock` |
| `DOCK_HYPRCTL` | Hyprland executable; `hyprctl` |
| `DOCK_QUICKSHELL` | Quickshell executable; `quickshell` |
| `DOCK_BACKEND` | Window dispatchers; `lua` or `classic` |

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

Use `DOCK_CONFIG_DIR=/tmp/dock-dev ./bin/dock` for isolated settings.
`qml/` contains the UI, `bin/dockctl` handles actions, and `bin/dock` launches
the same code from a checkout or installation.

Screenshots show the real UI with sample application favorites; desktop content
outside the dock and settings window is excluded.

## License

[MIT](LICENSE).
