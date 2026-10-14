"""Protocol integration test in a private D-Bus session, never the user's bus."""
import json
import os
from pathlib import Path
import select
import shutil
import subprocess
import sys
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


def has_gio():
    return (shutil.which("dbus-run-session") and Path("/usr/bin/python3").exists()
            and subprocess.run(["/usr/bin/python3", "-c", "import gi"], capture_output=True).returncode == 0)


class BadgeBusTest(unittest.TestCase):
    @unittest.skipUnless(has_gio(), "Needs dbus-run-session and system Python GObject")
    def test_launcher_protocol_and_sender_lifecycle(self):
        result = subprocess.run(["dbus-run-session", "--", "/usr/bin/python3", __file__, "--isolated"],
                                capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


def isolated_test():
    import gi
    gi.require_version("Gio", "2.0")
    from gi.repository import Gio, GLib
    helper = subprocess.Popen([sys.executable, str(ROOT / "bin/dock-badges")], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    buffer = b""
    def wait_for(predicate):
        nonlocal buffer
        deadline = time.monotonic() + 4
        while time.monotonic() < deadline:
            if b"\n" in buffer:
                line, buffer = buffer.split(b"\n", 1)
                value = json.loads(line)
                if predicate(value):
                    return value
                continue
            if select.select([helper.stdout], [], [], .1)[0]:
                chunk = os.read(helper.stdout.fileno(), 65536)
                if not chunk:
                    raise AssertionError(helper.stderr.read().decode())
                buffer += chunk
        raise AssertionError("Timed out waiting for badge state")

    def connection():
        return Gio.DBusConnection.new_for_address_sync(os.environ["DBUS_SESSION_BUS_ADDRESS"],
            Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT | Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION, None, None)

    def emit(bus, properties):
        bus.emit_signal(None, "/com/example/Launcher", "com.canonical.Unity.LauncherEntry", "Update",
                        GLib.Variant("(sa{sv})", ("application://org.example.Mail.desktop", properties)))
        bus.flush_sync(None)

    try:
        wait_for(lambda state: state["ownsUnityName"])
        first, second = connection(), connection()
        emit(first, {"count": GLib.Variant("x", 7), "count-visible": GLib.Variant("b", True),
                     "progress": GLib.Variant("d", .25), "progress-visible": GLib.Variant("b", True), "urgent": GLib.Variant("b", True)})
        value = wait_for(lambda state: state["entries"].get("org.example.Mail", {}).get("count") == 7)
        assert value["entries"]["org.example.Mail"]["urgent"]
        emit(first, {"count": GLib.Variant("x", 8)})
        value = wait_for(lambda state: state["entries"].get("org.example.Mail", {}).get("count") == 8)
        assert value["entries"]["org.example.Mail"]["progress"] == .25
        emit(second, {"count": GLib.Variant("x", 3), "count-visible": GLib.Variant("b", True)})
        wait_for(lambda state: state["entries"].get("org.example.Mail", {}).get("count") == 3)
        second.close_sync(None)
        wait_for(lambda state: state["entries"].get("org.example.Mail", {}).get("count") == 8)
        emit(first, {"count-visible": GLib.Variant("b", False), "progress-visible": GLib.Variant("b", False), "urgent": GLib.Variant("b", False)})
        value = wait_for(lambda state: state["entries"].get("org.example.Mail", {}).get("countVisible") is False)
        assert not value["entries"]["org.example.Mail"]["progressVisible"]
        first.close_sync(None)
        wait_for(lambda state: not state["entries"])
        helper.stdout.close()
        assert helper.wait(timeout=4) == 0, "Helper must exit when the UI's read pipe closes"
    finally:
        if helper.poll() is None:
            helper.terminate()
        helper.wait(timeout=5)


if __name__ == "__main__":
    if "--isolated" in sys.argv:
        isolated_test()
    else:
        unittest.main()
