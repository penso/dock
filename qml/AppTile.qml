import QtQuick
import QtQuick.Effects

Item {
    id: tile
    property string source: ""
    property color tileColor: "#35383e"
    property bool launcher: false
    Rectangle {
        anchors.fill: parent
        visible: tile.launcher
        radius: width * 0.225
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.lighter(tile.tileColor, 1.12) }
            GradientStop { position: 1; color: Qt.darker(tile.tileColor, 1.08) }
        }
        border.width: 0.7
        border.color: Qt.rgba(1, 1, 1, 0.13)
    }
    Image {
        anchors.fill: parent; anchors.margins: parent.width * 0.08
        visible: !tile.launcher
        source: tile.source; sourceSize: Qt.size(288, 288)
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        cache: false
        layer.enabled: true
        layer.mipmap: true
        layer.smooth: true
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowColor: "#50000000"
            shadowBlur: 0.25; shadowVerticalOffset: 1.5
        }
    }
    Grid {
        visible: tile.launcher; anchors.centerIn: parent
        columns: 3; spacing: tile.width * 0.075
        Repeater {
            model: 9
            Rectangle { width: tile.width * 0.12; height: width; radius: width * 0.3; color: "#dedee4" }
        }
    }
}
