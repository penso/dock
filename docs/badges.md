# Application badges and progress

Dock listens on session D-Bus for:

```text
interface: com.canonical.Unity.LauncherEntry
signal:    Update
signature: (sa{sv})
```

The first argument is an application URI such as
`application://org.gnome.Nautilus.desktop`. Supported properties:

| Property | Type | Meaning |
| --- | --- | --- |
| `count` | integer | Unread/task count |
| `count-visible` | boolean | Show a nonzero count |
| `progress` | double | Progress in the range 0–1 |
| `progress-visible` | boolean | Show the progress track |
| `urgent` | boolean | Request an attention outline |

Updates are partial: changing a count does not erase progress or visibility.
Fields with unexpected types are ignored, negative counts are clamped to zero,
and progress is clamped to 0–1. The UI caps the displayed count at `99+`, while
`dock ipc status` retains the numeric count and current activity state.

State is tracked per sending D-Bus connection and application ID. When multiple
senders report the same app, the latest update wins rather than summing duplicate
counts. Disconnecting removes only that sender's state and falls back to another
live sender, if any. State is not persisted across dock restarts.

The helper requests `com.canonical.Unity` without replacing an existing owner.
Libunity applications commonly republish state when that name appears. If a
different dock owns it, Dock still listens for subsequent updates. There is no
generic way to recover old counts from applications that do not republish them.

## Urgent windows

Hyprland's `urgent` events and Quickshell's toplevel state also produce an amber
outline and attention dot. Direct IPC tracking supports Quickshell builds that
do not reliably expose urgency through the toplevel property. Focusing or closing
the window clears this compositor-provided state.
Unity-provided urgency remains under the application's control. Urgency alone
never creates an invented unread count.

## Notification popups

Dock neither registers `org.freedesktop.Notifications` nor intercepts notification
messages. Mako, Dunst, or another notification daemon continues to display popups.
Badge support requires an application to publish LauncherEntry updates; a popup
by itself is not an unread counter.

## Try it

With Dock running, choose a desktop ID already pinned or running:

```sh
/usr/bin/python3 tools/demo-badges.py org.gnome.Nautilus --count 7 --progress .65 --urgent
```

The demo holds its D-Bus connection open. Press Ctrl+C to disconnect and clear
its updates. One-shot `gdbus emit` commands are not a useful visual test because
their sender exits immediately and its badges are removed.

The helper uses system Python's GObject/Gio bindings. If these live in another
interpreter, launch with `DOCK_DBUS_PYTHON=/path/to/python`. Failure of this helper
does not prevent the dock, normal window actions, or Hyprland urgency from working.

Tests exercise the state reducer, real signals and sender disconnection on an
isolated D-Bus session, model association, and QML indicator visibility. The
private-bus test never emits synthetic notifications on the user's session bus.
