import QtQuick
import QtQuick.Controls

Menu {
    id: menu
    required property var colors
    popupType: Popup.Window
    width: 280
    padding: 6
    margins: 10
    font.pixelSize: 13
    palette.window: colors.base
    palette.text: colors.text
    palette.buttonText: colors.text
    palette.highlightedText: colors.text
    palette.highlight: Qt.rgba(Qt.color(colors.blue).r, Qt.color(colors.blue).g, Qt.color(colors.blue).b, 0.22)
    palette.mid: Qt.rgba(Qt.color(colors.text).r, Qt.color(colors.text).g, Qt.color(colors.text).b, 0.12)
    delegate: DockMenuItem {}
    background: Rectangle {
        radius: 14
        color: Qt.rgba(Qt.color(menu.colors.base).r, Qt.color(menu.colors.base).g, Qt.color(menu.colors.base).b, 0.96)
        border.width: 1
        border.color: Qt.rgba(Qt.color(menu.colors.text).r, Qt.color(menu.colors.text).g, Qt.color(menu.colors.text).b, 0.17)
    }
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 110; easing.type: Easing.OutCubic } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 80 } }
}
