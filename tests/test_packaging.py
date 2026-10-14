import hashlib
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("package_arch", ROOT / "tools/package_arch.py")
packaging = importlib.util.module_from_spec(spec)
spec.loader.exec_module(packaging)


class PackagingTest(unittest.TestCase):
    def test_reproducible_archives_and_verified_release_recipe(self):
        with tempfile.TemporaryDirectory() as tmp:
            a = packaging.generate(ROOT, Path(tmp) / "a", "1.2.3", release=True)
            b = packaging.generate(ROOT, Path(tmp) / "b", "1.2.3", release=True)
            self.assertEqual(a.read_bytes(), b.read_bytes())
            recipe = (a.parent / "PKGBUILD").read_text()
            self.assertIn(hashlib.sha256(a.read_bytes()).hexdigest(), recipe)
            self.assertIn('source=("$url/releases/download/v$pkgver/dock-$pkgver.tar.gz")', recipe)
            self.assertIn("pkgver=1.2.3", recipe)
            self.assertNotIn("SKIP", recipe)
            with tarfile.open(a) as tar:
                names = tar.getnames()
                self.assertFalse(any("/tests/" in name or "/docs/media/" in name or "__pycache__" in name for name in names))
                self.assertIn("dock-1.2.3/qml/backends/WaylandBackend.qml", names)
                self.assertIn("dock-1.2.3/bin/dock-badges", names)
                self.assertEqual(tar.extractfile("dock-1.2.3/VERSION").read(), b"1.2.3\n")
            metadata = json.loads((a.parent / ".omarchy/package.json").read_text())
            self.assertEqual(metadata["source"], "local")
            self.assertEqual(metadata["upstream"]["watch"]["github"], "penso/dock")

    def test_package_function_installs_a_working_system_layout(self):
        with tempfile.TemporaryDirectory(prefix="dock-package-") as tmp:
            tmp = Path(tmp)
            archive = packaging.generate(ROOT, tmp / "recipe", "0.1.0")
            source, stage = tmp / "source", tmp / "stage"
            source.mkdir(); stage.mkdir()
            with tarfile.open(archive) as tar:
                tar.extractall(source, filter="data")
            subprocess.run(["bash", "-c", 'set -e; source "$1"; package', "bash", str(archive.parent / "PKGBUILD")],
                           env={**os.environ, "srcdir": str(source), "pkgdir": str(stage)}, check=True)
            for path in ("usr/bin/dock", "usr/share/dock/bin/dock-session", "usr/share/dock/bin/dock-badges",
                         "usr/lib/systemd/user/dock.service", "usr/share/applications/io.github.penso.dock.desktop",
                         "usr/share/licenses/dock-quickshell/LICENSE"):
                self.assertTrue((stage / path).is_file(), path)
            home = tmp / "home"
            home.mkdir()
            env = {k: v for k, v in os.environ.items() if not k.startswith("DOCK_") and k != "HYPRLAND_INSTANCE_SIGNATURE"}
            env.update(HOME=str(home), XDG_CONFIG_HOME=str(home / "config"), XDG_DATA_HOME=str(home / "data"), DOCK_COMPOSITOR="wayland")
            result = subprocess.run([str(stage / "usr/bin/dock"), "ctl", "status"], env=env, text=True, capture_output=True, check=True)
            self.assertEqual(json.loads(result.stdout)["dock"]["position"], "bottom")
            self.assertTrue((home / "config/dock/settings.json").exists())
            self.assertFalse((home / "data/dock/qml").exists(), "Native launcher must use the package's shared data")

    def test_invalid_versions_are_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            with self.assertRaises(ValueError):
                packaging.generate(ROOT, Path(tmp), "1.0;echo invalid")


if __name__ == "__main__":
    unittest.main()
