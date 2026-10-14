import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class BackendSelectionTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dock-backend-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.output = self.home / "args.json"
        qs = self.home / "fake-quickshell"
        qs.write_text('#!/usr/bin/env python3\nimport os,sys,json\nopen(os.environ["DOCK_TEST_ARGS"], "w").write(json.dumps(sys.argv[1:]))\n')
        qs.chmod(0o755)
        self.env = {k: v for k, v in os.environ.items() if not k.startswith("DOCK_") and k != "HYPRLAND_INSTANCE_SIGNATURE"}
        self.env.update(HOME=str(self.home), DOCK_CONFIG_DIR=str(self.home / "config"),
                        DOCK_QUICKSHELL=str(qs), DOCK_TEST_ARGS=str(self.output), DOCK_HYPRCTL="/nonexistent/hyprctl")

    def invoke(self, *args):
        return subprocess.run([str(ROOT / "bin/dock"), *args], env=self.env, capture_output=True, text=True)

    def test_auto_without_hyprland_routes_minimize_through_wayland_ipc(self):
        result = self.invoke("ctl", "minimize")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.output.read_text())[-4:], ["ipc", "call", "dock", "minimize"])

    def test_forced_wayland_overrides_hyprland_session(self):
        self.env.update(DOCK_COMPOSITOR="wayland", HYPRLAND_INSTANCE_SIGNATURE="existing-session")
        result = self.invoke("ctl", "restore")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(json.loads(self.output.read_text())[-1], "restore")

    def test_invalid_backend_does_not_create_configuration(self):
        self.env["DOCK_COMPOSITOR"] = "unsupported"
        self.assertEqual(self.invoke("ctl", "init").returncode, 2)
        self.assertFalse((self.home / "config").exists())

    def test_generic_address_actions_explain_portable_alternative(self):
        result = self.invoke("ctl", "focus", "0x123")
        self.assertEqual(result.returncode, 2)
        self.assertIn("dock ipc activate APP_ID", result.stderr)
        self.assertFalse(self.output.exists())


if __name__ == "__main__":
    unittest.main()
