import importlib.machinery
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from urllib.parse import unquote, urlsplit

try:
    from PIL import Image
except ImportError:
    Image = None

loader = importlib.machinery.SourceFileLoader("dock_icons", str(Path(__file__).resolve().parents[1] / "bin/dock-icons"))
spec = importlib.util.spec_from_loader(loader.name, loader)
icons = importlib.util.module_from_spec(spec)
loader.exec_module(icons)


@unittest.skipIf(Image is None, "Pillow is needed for the optional Lanczos renderer")
class IconCacheTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / "icon with spaces.png"
        image = Image.new("RGBA", (128, 128), (255, 0, 0, 0))
        image.paste((0, 0, 255, 255), (32, 32, 96, 96))
        image.save(self.source)

    def test_cache_reuses_pixels_and_invalidates_changed_artwork(self):
        first = icons.build_atlas(self.source, 40, 80, self.root / "cache")
        with patch.object(icons, "load_image", side_effect=AssertionError("Cache hit should not rasterize")):
            self.assertEqual(icons.build_atlas(self.source, 40, 80, self.root / "cache"), first)
        Image.new("RGBA", (128, 128), "green").save(self.source)
        second = icons.build_atlas(self.source, 40, 80, self.root / "cache")
        self.assertNotEqual(first["url"], second["url"])

    def test_lanczos_filters_alpha_without_transparent_red_fringes(self):
        entry = icons.build_atlas(self.source, 31, 62, self.root / "cache")
        atlas = Image.open(unquote(urlsplit(entry["url"]).path))
        level = atlas.crop((2, 2, 33, 33))
        edge = [level.getpixel((x, y)) for y in range(level.height) for x in range(level.width)
                if 0 < level.getpixel((x, y))[3] < 255]
        self.assertTrue(edge, "Lanczos should produce antialiased edge coverage")
        self.assertTrue(all(r == 0 and g == 0 and b == 255 for r, g, b, a in edge))
        self.assertEqual(atlas.getpixel((0, 0)), (0, 0, 0, 0))
        self.assertEqual(atlas.size, (entry["cell"] * 3,) * 2)

    def test_display_scale_and_maximum_magnification(self):
        request = {"size": 40, "scale": 1.5, "magnification": 2, "sources": [self.source.as_uri()]}
        result = icons.process(request, self.root / "cache")[self.source.as_uri()]
        self.assertEqual(result["minimum"], 51)
        self.assertGreaterEqual(result["minimum"] + result["step"] * 8, 101)
        self.assertEqual(icons.resolve("image://icon/" + str(self.source)), self.source)
        with self.assertRaises(ValueError):
            icons.process({**request, "scale": float("nan")}, self.root / "cache")

    def test_nonsquare_artwork_preserves_aspect_ratio(self):
        Image.new("RGBA", (120, 60), "white").save(self.source)
        entry = icons.build_atlas(self.source, 40, 80, self.root / "cache")
        atlas = Image.open(unquote(urlsplit(entry["url"]).path))
        self.assertEqual(atlas.crop((2, 2, 42, 42)).getbbox(), (0, 10, 40, 30))

    def test_missing_icon_retains_other_results(self):
        request = {"size": 40, "scale": 1, "magnification": 2,
                   "sources": [self.source.as_uri(), (self.root / "missing.png").as_uri()]}
        result = icons.process(request, self.root / "cache")
        self.assertEqual(list(result), [self.source.as_uri()])
