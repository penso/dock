import importlib.machinery
import importlib.util
import os
from pathlib import Path
import unittest
from unittest.mock import patch, call

SCRIPT = Path(__file__).resolve().parents[1] / "bin/dock-session"
loader = importlib.machinery.SourceFileLoader("dock_session", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
session = importlib.util.module_from_spec(spec)
loader.exec_module(session)


class SessionTest(unittest.TestCase):
    def invoke(self, *args):
        with patch("sys.argv", [str(SCRIPT), *args]), patch.object(session, "run") as run:
            session.main()
            return run.call_args_list

    def test_enable_imports_session_and_does_not_persist_detected_backend(self):
        with patch.dict(os.environ, {"WAYLAND_DISPLAY": "wayland-1", "HYPRLAND_INSTANCE_SIGNATURE": "test", "DOCK_BACKEND": "lua"}, clear=True):
            commands = self.invoke("enable")
        self.assertEqual(commands[0], call("dbus-update-activation-environment", "--systemd", "WAYLAND_DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE"))
        self.assertEqual(commands[-1], call("systemctl", "--user", "enable", "--now", "dock.service"))

    def test_enable_without_start_and_disable(self):
        with patch.dict(os.environ, {}, clear=True):
            self.assertEqual(self.invoke("enable", "--no-start")[-1], call("systemctl", "--user", "enable", "dock.service"))
            self.assertEqual(self.invoke("disable"), [call("systemctl", "--user", "disable", "--now", "dock.service")])


if __name__ == "__main__":
    unittest.main()
