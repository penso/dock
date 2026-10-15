import importlib.machinery
import importlib.util
import os
from pathlib import Path
import tempfile
import subprocess
import unittest

loader = importlib.machinery.SourceFileLoader("dock_trash", str(Path(__file__).resolve().parents[1] / "bin/dock-trash"))
spec = importlib.util.spec_from_loader(loader.name, loader)
trash = importlib.util.module_from_spec(spec)
loader.exec_module(trash)


class TrashIconTest(unittest.TestCase):
    def test_distinct_gnome_icons_are_selected_from_data_dirs(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            empty = root / "icons/Adwaita/scalable/places/user-trash.svg"
            full = root / "icons/Adwaita/scalable/status/user-trash-full.svg"
            for path in (empty, full):
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text('<svg xmlns="http://www.w3.org/2000/svg"/>')
            self.assertEqual(trash.gnome_icons([root]), {"emptyIcon": empty.as_uri(), "fullIcon": full.as_uri()})

    def test_missing_theme_leaves_fallback_available(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(trash.gnome_icons([tmp]), {"emptyIcon": "", "fullIcon": ""})

    def test_rasterization_preserves_alpha_and_distinct_cached_states(self):
        available = subprocess.run(['/usr/bin/python3', '-c', 'import gi; gi.require_version("GdkPixbuf", "2.0"); from gi.repository import GdkPixbuf'], capture_output=True)
        if available.returncode:
            self.skipTest('System Python GdkPixbuf bindings are unavailable')
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name, color in (("empty", "green"), ("full", "blue")):
                (root / f"{name}.svg").write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><rect x="4" y="4" width="24" height="24" fill="{color}"/></svg>')
            script = '''
import importlib.machinery, importlib.util, sys
from pathlib import Path
from urllib.parse import urlsplit, unquote
loader=importlib.machinery.SourceFileLoader('trash',sys.argv[1])
spec=importlib.util.spec_from_loader(loader.name,loader)
module=importlib.util.module_from_spec(spec);loader.exec_module(module)
root=Path(sys.argv[2]); icons={name:(root/(name+'.svg')).as_uri() for name in ('empty','full')}
result=module.rasterized_icons(icons)
assert result['empty'] != result['full']
from gi.repository import GdkPixbuf
for uri in result.values():
    path=Path(unquote(urlsplit(uri).path)); assert path.suffix == '.png'
    pixbuf=GdkPixbuf.Pixbuf.new_from_file(str(path))
    assert pixbuf.get_has_alpha() and pixbuf.get_pixels()[3] == 0
    assert pixbuf.get_width() == 256
assert module.rasterized_icons(icons) == result
'''
            subprocess.run(['/usr/bin/python3', '-c', script, str(Path(__file__).resolve().parents[1] / 'bin/dock-trash'), str(root)],
                           env={**os.environ, 'XDG_CACHE_HOME': str(root / 'cache')}, check=True)


if __name__ == "__main__":
    unittest.main()
