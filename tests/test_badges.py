import importlib.machinery
import importlib.util
from pathlib import Path
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "bin/dock-badges"
loader = importlib.machinery.SourceFileLoader("dock_badges", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
badges = importlib.util.module_from_spec(spec)
loader.exec_module(badges)


class BadgeStateTest(unittest.TestCase):
    def test_uri_normalization_preserves_case_and_rejects_other_schemes(self):
        self.assertEqual(badges.desktop_id("application://org.gnome.Nautilus.desktop"), "org.gnome.Nautilus")
        self.assertEqual(badges.desktop_id("application://org.example.%41pp.desktop"), "org.example.App")
        for uri in ("file:///app.desktop", "application://../app.desktop", "application://app", "application://%00.desktop"):
            self.assertIsNone(badges.desktop_id(uri))

    def test_partial_updates_and_explicit_visibility(self):
        state = badges.LauncherState()
        uri = "application://mail.desktop"
        state.update(":1.10", uri, {"count": 7, "count-visible": True, "progress": .4, "progress-visible": True})
        state.update(":1.10", uri, {"count": 9, "urgent": True})
        item = state.snapshot()["mail"]
        self.assertEqual(item, {"count": 9, "countVisible": True, "progress": .4, "progressVisible": True, "urgent": True})
        state.update(":1.10", uri, {"count-visible": False, "progress-visible": False, "urgent": False})
        item = state.snapshot()["mail"]
        self.assertEqual(item["count"], 9)
        self.assertFalse(item["countVisible"])
        self.assertFalse(item["progressVisible"])
        self.assertFalse(item["urgent"])

    def test_disconnected_sender_clears_only_its_own_state(self):
        state = badges.LauncherState()
        state.update(":1.10", "application://mail.desktop", {"count": 7})
        state.update(":1.11", "application://mail.desktop", {"count": 3})
        state.update(":1.12", "application://files.desktop", {"progress": .2})
        self.assertEqual(state.snapshot()["mail"]["count"], 3)
        state.remove_sender(":1.11")
        self.assertEqual(state.snapshot()["mail"]["count"], 7)
        state.remove_sender(":1.10")
        self.assertNotIn("mail", state.snapshot())
        self.assertIn("files", state.snapshot())

    def test_malformed_fields_cannot_corrupt_valid_state(self):
        state = badges.LauncherState()
        uri = "application://app.desktop"
        state.update(":1.1", uri, {"count": 4, "progress": .5})
        self.assertFalse(state.update(":1.1", uri, {"count": True, "count-visible": "yes", "progress": float("nan"), "quicklist": "/ignored"}))
        self.assertEqual(state.snapshot()["app"]["count"], 4)
        state.update(":1.1", uri, {"count": -5, "progress": 10})
        self.assertEqual(state.snapshot()["app"]["count"], 0)
        self.assertEqual(state.snapshot()["app"]["progress"], 1)


if __name__ == "__main__":
    unittest.main()
