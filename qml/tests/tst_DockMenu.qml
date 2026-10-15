import QtQuick
import QtQuick.Controls
import QtTest
import ".." as Dock

Item {
    id: scene
    width: 900; height: 650
    Rectangle { id: icon; x: 350; y: 350; width: 48; height: 48; color: "blue" }
    Dock.DockMenu {
        id: menu
        popupType: Popup.Item
        colors: ({base: "#111111", text: "#ffffff", blue: "#007aff"})
        Dock.DockMenuItem { text: "Show All Windows" }
        Dock.DockMenuSeparator {}
        Dock.DockMenuItem { text: "Quit" }
    }
    TestCase {
        name: "DockMenu"
        when: windowShown
        function cleanup() { menu.close(); wait(100); icon.x = 350; icon.y = 350 }
        function test_pointsToIconInsteadOfMousePosition() {
            menu.popupFor(icon, "bottom", scene)
            tryCompare(menu, "opened", true)
            verify(menu.pointed)
            fuzzyCompare(menu.x + 28, icon.width / 2, 0.1)
            fuzzyCompare(menu.y + menu.height, -14, 0.1)
            compare(menu.palette.text, Qt.color("#202124"))
            compare(menu.itemAt(0).implicitHeight, 26)
        }
        function test_flipsForOtherDockEdges() {
            menu.popupFor(icon, "left", scene)
            tryCompare(menu, "opened", true)
            fuzzyCompare(menu.x, icon.width + 14, 0.1)
            menu.close(); wait(100)
            menu.popupFor(icon, "top", scene)
            tryCompare(menu, "opened", true)
            fuzzyCompare(menu.y, icon.height + 14, 0.1)
        }
        function test_staysWithinPanelAtRightEdge() {
            icon.x = 840
            menu.popupFor(icon, "bottom", scene)
            tryCompare(menu, "opened", true)
            verify(icon.x + menu.x + menu.width <= scene.width - 11)
        }
    }
}
