import importlib.machinery
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


SCRIPT = Path(__file__).resolve().parents[1] / "bin/penso-dockctl"
loader = importlib.machinery.SourceFileLoader("dock_actions", str(SCRIPT))
spec = importlib.util.spec_from_loader(loader.name, loader)
actions = importlib.util.module_from_spec(spec)
loader.exec_module(actions)


class DockActionsTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.config = Path(self.temp.name) / "settings.json"
        self.config.write_text(json.dumps({
            "default": "floating", "workspaces": {"2": "dwindle"},
            "dock": {"pinned": ["a", "b", "c"], "autohide": False},
        }))
        for name, value in (("CONFIG", self.config),):
            patcher = patch.object(actions, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)

    def run_action(self, *args):
        with patch("sys.argv", [str(SCRIPT), *args]):
            actions.main()
        return json.loads(self.config.read_text())

    def test_pin_new_running_app_and_move_without_duplicates(self):
        result = self.run_action("pin-at", "new.desktop", "1")
        self.assertEqual(result["dock"]["pinned"], ["a", "new", "b", "c"])
        result = self.run_action("pin-at", "a", "3")
        self.assertEqual(result["dock"]["pinned"], ["new", "b", "c", "a"])
        self.assertEqual(result["workspaces"], {"2": "dwindle"})

    def test_pin_position_is_bounded_and_id_is_validated(self):
        self.assertEqual(self.run_action("pin-at", "c", "-10")["dock"]["pinned"], ["c", "a", "b"])
        self.assertEqual(self.run_action("pin-at", "c", "99")["dock"]["pinned"], ["a", "b", "c"])
        before = self.config.read_text()
        with self.assertRaises(SystemExit):
            self.run_action("pin-at", "../invalid", "0")
        self.assertEqual(self.config.read_text(), before)

    def test_close_targets_only_the_requested_window(self):
        with patch.object(actions, "ctl", return_value=[{"address": "0x123"}]), patch.object(actions, "dispatch") as dispatch:
            self.run_action("close", "0x123")
            dispatch.assert_called_once_with('hl.dsp.window.close({ window = "address:0x123" })', 'closewindow', 'address:0x123')
            dispatch.reset_mock()
            self.run_action("close", "0x456")
            dispatch.assert_not_called()
            with self.assertRaises(ValueError):
                self.run_action("close", '0x123" })')
            dispatch.assert_not_called()

    def test_init_preserves_preferences_and_creates_theme(self):
        before = json.loads(self.config.read_text())
        self.run_action("init")
        self.assertEqual(json.loads(self.config.read_text())["dock"]["pinned"], before["dock"]["pinned"])
        theme = self.config.parent / "theme.json"
        self.assertTrue(theme.exists())
        theme.write_text('{"base": "#123456"}')
        self.run_action("init")
        self.assertEqual(json.loads(theme.read_text())["base"], "#123456")

    def test_appearance_bounds_do_not_overwrite_saved_settings(self):
        self.assertEqual(self.run_action("appearance", "72", "200")["dock"]["size"], 72)
        before = self.config.read_text()
        with self.assertRaises(SystemExit):
            self.run_action("appearance", "200", "300")
        self.assertEqual(self.config.read_text(), before)

    def test_restore_moves_minimized_window_before_focus(self):
        client = {"address": "0x123", "workspace": {"name": "special:minimized"}}
        with patch.object(actions, "window", return_value=client), patch.object(actions, "ctl", return_value={"id": 2}), patch.object(actions, "dispatch") as dispatch:
            actions.restore("0x123")
            self.assertEqual(dispatch.call_count, 3)
            self.assertEqual(dispatch.call_args_list[0].args[1:], ("movetoworkspacesilent", "2,address:0x123"))
            self.assertEqual(dispatch.call_args_list[1].args[1:], ("focuswindow", "address:0x123"))

    def test_classic_backend_uses_argument_array(self):
        with patch.object(actions, "BACKEND", "classic"), patch.object(actions, "ctl") as ctl:
            actions.dispatch("unused Lua", "closewindow", "address:0x123")
            ctl.assert_called_once_with("dispatch", "closewindow", "address:0x123")

    def test_appearance_preserves_pins_and_workspace_modes(self):
        result = self.run_action("appearance", "72", "200")
        self.assertEqual(result["dock"]["size"], 72)
        self.assertEqual(result["dock"]["magnification"], 200)
        self.assertEqual(result["dock"]["pinned"], ["a", "b", "c"])
        self.assertEqual(result["workspaces"], {"2": "dwindle"})
        with self.assertRaises(SystemExit):
            self.run_action("appearance", "100", "200")


if __name__ == "__main__":
    unittest.main()
