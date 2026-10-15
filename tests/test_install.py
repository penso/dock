import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class InstallTest(unittest.TestCase):
    def test_install_into_custom_xdg_paths_and_preserve_settings(self):
        with tempfile.TemporaryDirectory(prefix="dock install ") as tmp:
            home = Path(tmp)
            env = {k: v for k, v in os.environ.items() if not k.startswith("DOCK_") and k != "HYPRLAND_INSTANCE_SIGNATURE"}
            env.update(HOME=str(home), XDG_CONFIG_HOME=str(home / "config"), XDG_DATA_HOME=str(home / "data"))
            subprocess.run(["python3", str(ROOT / "install.py")], env=env, check=True, capture_output=True)
            launcher = home / ".local/bin/dock"
            subprocess.run([str(launcher), "ctl", "pin", "org.example.App"], env=env, check=True)
            subprocess.run(["python3", str(ROOT / "install.py")], env=env, check=True, capture_output=True)
            settings = json.loads((home / "config/dock/settings.json").read_text())
            self.assertEqual(settings["dock"]["pinned"], ["org.example.App"])
            self.assertTrue((home / "data/dock/qml/shell.qml").is_file())
            self.assertTrue((home / "data/dock/bin/dock-badges").is_file())
            self.assertTrue((home / "data/dock/bin/dock-trash").is_file())
            self.assertTrue((home / "data/dock/qml/DockIndicators.qml").is_file())
            self.assertTrue((home / "config/systemd/user/dock.service").is_file())
            self.assertFalse((home / ".config/penso-floating").exists())


if __name__ == "__main__":
    unittest.main()
