import QtQuick
import QtQuick.Effects

Item {
    id: tile
    property string source: ""
    property color tileColor: "#35383e"
    property bool launcher: false
    property var atlasEntry: null
    property bool lanczosEnabled: true
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
    Item {
        id: artwork
        anchors.fill: parent; anchors.margins: parent.width * 0.08
        visible: !tile.launcher
        readonly property bool useAtlas: tile.lanczosEnabled && tile.atlasEntry !== null
            && atlasTexture.status === Image.Ready && GraphicsInfo.api !== GraphicsInfo.Software
        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            shadowEnabled: true; shadowColor: "#50000000"
            shadowBlur: 0.25; shadowVerticalOffset: 1.5
        }
        Image {
            anchors.fill: parent
            visible: !artwork.useAtlas
            source: tile.source; sourceSize: Qt.size(288, 288)
            fillMode: Image.PreserveAspectFit
            smooth: true; mipmap: true; cache: false
        }
        Image {
            id: atlasTexture
            visible: false
            source: tile.lanczosEnabled && tile.atlasEntry ? tile.atlasEntry.url : ""
            asynchronous: true; smooth: true
        }
        ShaderEffect {
            anchors.fill: parent
            visible: artwork.useAtlas
            property var atlas: atlasTexture
            property vector4d atlasMetrics: tile.atlasEntry
                ? Qt.vector4d(tile.atlasEntry.minimum, tile.atlasEntry.step, tile.atlasEntry.cell, artwork.width * Screen.devicePixelRatio)
                : Qt.vector4d(1, 1, 1, 1)
            fragmentShader: Qt.resolvedUrl("shaders/icon-atlas.frag.qsb")
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
