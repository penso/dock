import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipIf(os.geteuid() == 0, "Omarchy setup intentionally refuses root")
class OmarchySetupTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="dock-omarchy-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.log = self.home / "commands.jsonl"
        commands = self.home / "commands"
        commands.mkdir()
        stub = '''#!/usr/bin/env python3
import json,os,sys
name=os.path.basename(sys.argv[0])
with open(os.environ['DOCK_TEST_LOG'],'a') as out:
    out.write(json.dumps([name,*sys.argv[1:]])+'\\n')
if name == 'makepkg' and os.environ.get('DOCK_TEST_FAIL_BUILD'):
    sys.exit(9)
'''
        for name in ("omarchy-pkg-add", "pacman", "makepkg", "dock", "omarchy-plugin-disable"):
            path = commands / name
            path.write_text(stub)
            path.chmod(0o755)
        omarchy = self.home / "omarchy"
        manifest = omarchy / "shell/plugins/dock/manifest.json"
        manifest.parent.mkdir(parents=True)
        manifest.write_text('{"id":"omarchy.dock"}')
        self.env = {**os.environ, "HOME": str(self.home), "XDG_CONFIG_HOME": str(self.home / "config"),
                    "PATH": str(commands) + ":" + os.environ["PATH"], "OMARCHY_PATH": str(omarchy),
                    "DOCK_TEST_LOG": str(self.log), "TMPDIR": str(self.home)}

    def commands(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def invoke(self, *args):
        return subprocess.run([str(ROOT / "install-omarchy.sh"), *args], env=self.env, capture_output=True, text=True)

    def test_normal_setup_installs_before_replacing_and_starting_dock(self):
        result = self.invoke()
        self.assertEqual(result.returncode, 0, result.stderr)
        commands = self.commands()
        self.assertEqual(commands[0][0], "omarchy-pkg-add")
        self.assertIn("quickshell", commands[0])
        self.assertEqual(commands[1][0], "makepkg")
        self.assertEqual(commands[-3:], [["omarchy-plugin-disable", "omarchy.dock"], ["dock", "enable", "--no-start"], ["dock", "restart"]])
        self.assertFalse(list(self.home.glob("dock-package.*")))

    def test_failure_keeps_existing_shell_dock_and_autostart_untouched(self):
        self.env["DOCK_TEST_FAIL_BUILD"] = "1"
        self.assertEqual(self.invoke().returncode, 9)
        self.assertEqual([cmd[0] for cmd in self.commands()], ["omarchy-pkg-add", "makepkg"])

    def test_no_start_and_keep_plugin_options(self):
        self.assertEqual(self.invoke("--no-start").returncode, 0)
        self.assertEqual(self.commands()[-1], ["dock", "enable", "--no-start"])
        self.assertFalse(any(cmd[0] == "omarchy-plugin-disable" for cmd in self.commands()))
        self.log.unlink()
        self.assertEqual(self.invoke("--keep-omarchy-dock").returncode, 0)
        self.assertFalse(any(cmd[0] == "omarchy-plugin-disable" for cmd in self.commands()))

    def test_user_local_install_is_not_overwritten(self):
        local = self.home / ".local/bin/dock"
        local.parent.mkdir(parents=True)
        local.write_text("user-owned launcher")
        result = self.invoke()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(local.read_text(), "user-owned launcher")
        self.assertEqual(self.commands(), [])


if __name__ == "__main__":
    unittest.main()
