#!/usr/bin/env python3
"""Publish sample launcher state until Ctrl+C; use an installed desktop ID."""
import argparse
import gi

gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("desktop_id")
parser.add_argument("--count", type=int, default=7)
parser.add_argument("--progress", type=float)
parser.add_argument("--urgent", action="store_true")
args = parser.parse_args()
if args.progress is not None and not 0 <= args.progress <= 1:
    parser.error("--progress must be between 0 and 1")
app = args.desktop_id.removesuffix(".desktop")
bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
properties = {
    "count": GLib.Variant("x", max(0, args.count)),
    "count-visible": GLib.Variant("b", args.count > 0),
    "progress": GLib.Variant("d", args.progress or 0),
    "progress-visible": GLib.Variant("b", args.progress is not None),
    "urgent": GLib.Variant("b", args.urgent),
}
bus.emit_signal(None, "/com/example/DockDemo", "com.canonical.Unity.LauncherEntry", "Update",
                GLib.Variant("(sa{sv})", (f"application://{app}.desktop", properties)))
bus.flush_sync(None)
print(f"Showing sample activity for {app}. Press Ctrl+C to clear it.", flush=True)
try:
    GLib.MainLoop().run()
except KeyboardInterrupt:
    pass
