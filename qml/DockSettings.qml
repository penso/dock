import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

FloatingWindow {
    id: panel
    required property var controller
    visible: controller.dockSettingsOpen
    title: "Dock Settings"
    implicitWidth: 440
    implicitHeight: 390
    minimumSize: Qt.size(440, 390)
    color: controller.palette.base
    function flush() { if (saveDelay.running) { saveDelay.stop(); controller.saveAppearance() } }
    function close() { flush(); controller.dockSettingsOpen = false }
    onClosed: close()
    onVisibleChanged: {
        if (visible) {
            sizeSlider.value = controller.dockSize
            magnifySlider.value = controller.dockMagnification
            body.forceActiveFocus()
        } else flush()
    }
    Timer { id: saveDelay; interval: 300; onTriggered: controller.saveAppearance() }
    component SettingsButton: Button {
        implicitHeight: 32
        contentItem: Text {
            text: parent.text; font: parent.font
            color: parent.checked ? panel.controller.palette.base : panel.controller.palette.text
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 8
            color: parent.checked ? panel.controller.palette.blue : parent.flat && !parent.hovered ? "transparent" : panel.controller.palette.surface
            border.width: parent.activeFocus ? 1 : 0
            border.color: panel.controller.palette.blue
        }
    }
    component SettingsSlider: Slider {
        implicitHeight: 24
        background: Rectangle {
            x: parent.leftPadding; y: parent.topPadding + parent.availableHeight / 2 - height / 2
            width: parent.availableWidth; height: 5; radius: 3
            color: panel.controller.palette.surface
            Rectangle { width: parent.parent.visualPosition * parent.width; height: parent.height; radius: 3; color: panel.controller.palette.blue }
        }
        handle: Rectangle {
            x: parent.leftPadding + parent.visualPosition * (parent.availableWidth - width)
            y: parent.topPadding + parent.availableHeight / 2 - height / 2
            width: 18; height: 18; radius: 9
            color: panel.controller.palette.text
            border.width: parent.activeFocus ? 2 : 1
            border.color: panel.controller.palette.blue
        }
    }
    Rectangle {
        id: body
        anchors.fill: parent
        color: panel.controller.palette.base
        Keys.onEscapePressed: panel.close()
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 24; spacing: 14
            RowLayout {
                Layout.fillWidth: true
                Text { text: "Dock Settings"; color: panel.controller.palette.text; font.pixelSize: 22; font.weight: Font.DemiBold; Layout.fillWidth: true }
            }
            Text { text: "Changes preview live and save automatically."; color: panel.controller.palette.muted; font.pixelSize: 12 }
            RowLayout {
                Text { text: "Dock size"; color: panel.controller.palette.text; Layout.fillWidth: true }
                Text { text: Math.round(sizeSlider.value) + " px"; color: panel.controller.palette.muted }
            }
            SettingsSlider {
                id: sizeSlider; Layout.fillWidth: true
                from: 24; to: 72; stepSize: 2; snapMode: Slider.SnapAlways
                Accessible.name: "Dock icon size"
                onMoved: { panel.controller.previewAppearance(Math.round(value), Math.round(magnifySlider.value)); saveDelay.restart() }
            }
            RowLayout {
                Text { text: "Magnification"; color: panel.controller.palette.text; Layout.fillWidth: true }
                Text { text: Math.round(magnifySlider.value) === 100 ? "Off" : Math.round(magnifySlider.value) + "%"; color: panel.controller.palette.muted }
            }
            SettingsSlider {
                id: magnifySlider; Layout.fillWidth: true
                from: 100; to: 200; stepSize: 1; snapMode: Slider.SnapAlways
                Accessible.name: "Maximum hover magnification"
                onMoved: { panel.controller.previewAppearance(Math.round(sizeSlider.value), Math.round(value)); saveDelay.restart() }
            }
            Text { text: "Position on screen"; color: panel.controller.palette.text }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Repeater {
                    model: ["Left", "Bottom", "Right", "Top"]
                    SettingsButton {
                        required property string modelData
                        Layout.fillWidth: true
                        text: modelData; checkable: true; autoExclusive: true
                        checked: panel.controller.edge === modelData.toLowerCase()
                        onClicked: { panel.flush(); panel.controller.action(["position", modelData.toLowerCase()]) }
                    }
                }
            }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.fillWidth: true
                SettingsButton {
                    text: "Reset size & magnification"; flat: true
                    onClicked: {
                        sizeSlider.value = 40; magnifySlider.value = 132
                        panel.controller.previewAppearance(40, 132); saveDelay.restart()
                    }
                }
                Item { Layout.fillWidth: true }
                SettingsButton { text: "Done"; onClicked: panel.close() }
            }
        }
    }
}
