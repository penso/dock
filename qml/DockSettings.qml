import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

FloatingWindow {
    id: panel
    required property var controller
    visible: controller.dockSettingsOpen
    title: "Dock Settings"
    implicitWidth: 480
    implicitHeight: 760
    minimumSize: Qt.size(480, 480)
    color: controller.palette.base
    function flush() { if (saveDelay.running) { saveDelay.stop(); controller.saveAppearance() } }
    function changeStyle(values) { controller.previewStyle(values); saveDelay.restart() }
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
    component SettingsToggle: Switch {
        id: toggle
        Layout.fillWidth: true
        implicitHeight: 38
        contentItem: Text {
            text: toggle.text; color: panel.controller.palette.text
            leftPadding: 56; verticalAlignment: Text.AlignVCenter
        }
        indicator: Rectangle {
            width: 42; height: 24; radius: 12; y: (toggle.height - height) / 2
            color: toggle.checked ? panel.controller.palette.blue : panel.controller.palette.surface
            border.width: toggle.visualFocus ? 2 : 0; border.color: panel.controller.palette.text
            Rectangle {
                x: toggle.checked ? 21 : 3; y: 3; width: 18; height: 18; radius: 9
                color: toggle.checked ? panel.controller.palette.base : panel.controller.palette.text
                Behavior on x { NumberAnimation { duration: 120 } }
            }
        }
    }
    component SettingsButton: Button {
        id: settingsButton
        implicitWidth: Math.max(80, implicitContentWidth + leftPadding + rightPadding)
        implicitHeight: Math.max(42, implicitContentHeight + topPadding + bottomPadding)
        leftPadding: 18; rightPadding: 18; topPadding: 11; bottomPadding: 11
        hoverEnabled: true
        font.pixelSize: 14; font.weight: Font.DemiBold
        contentItem: Text {
            text: settingsButton.text; font: settingsButton.font
            color: settingsButton.checked ? panel.controller.palette.base : panel.controller.palette.text
            horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
        }
        background: Rectangle {
            radius: 10
            color: settingsButton.checked
                ? (settingsButton.down ? Qt.darker(panel.controller.palette.blue, 1.15) : settingsButton.hovered ? Qt.lighter(panel.controller.palette.blue, 1.1) : panel.controller.palette.blue)
                : settingsButton.down ? panel.controller.alpha(panel.controller.palette.blue, 0.25)
                : settingsButton.hovered ? Qt.lighter(panel.controller.palette.surface, 1.2)
                : settingsButton.flat ? "transparent" : panel.controller.palette.surface
            border.width: settingsButton.flat ? 0 : 1
            border.color: panel.controller.alpha(panel.controller.palette.text, 0.1)
            Behavior on color { ColorAnimation { duration: 110 } }
            Rectangle {
                anchors.fill: parent; anchors.margins: -3; radius: 13; color: "transparent"
                visible: settingsButton.visualFocus
                border.width: 2; border.color: panel.controller.alpha(panel.controller.palette.blue, 0.7)
            }
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
        ScrollView {
            id: settingsScroll
            anchors.fill: parent; anchors.margins: 24
            contentWidth: availableWidth
            ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
            ScrollBar.vertical: ScrollBar {
                parent: body
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
            }
        ColumnLayout {
            width: settingsScroll.availableWidth; spacing: 14
            RowLayout {
                Layout.fillWidth: true
                Text { text: "Dock Settings"; color: panel.controller.palette.text; font.pixelSize: 22; font.weight: Font.DemiBold; Layout.fillWidth: true }
            }
            Text { text: "Changes preview live and save automatically."; color: panel.controller.palette.muted; font.pixelSize: 12 }
            Text { text: "Theme"; color: panel.controller.palette.text; font.weight: Font.DemiBold }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Repeater {
                    model: ["Desktop", "Glass", "Minimal", "Raised"]
                    SettingsButton {
                        required property string modelData
                        Layout.fillWidth: true; Layout.preferredWidth: 0
                        leftPadding: 10; rightPadding: 10
                        text: modelData; checked: panel.controller.dockStyle.theme === modelData.toLowerCase()
                        onClicked: { panel.controller.selectDockTheme(modelData.toLowerCase()); saveDelay.restart() }
                    }
                }
            }
            Text {
                Layout.fillWidth: true; wrapMode: Text.Wrap
                text: (panel.controller.dockStyle.theme === "custom" ? "Custom · " : "") + "Presets follow your desktop colors. Fine-tune them below."
                color: panel.controller.palette.muted; font.pixelSize: 12
            }
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
            RowLayout {
                Text { text: "Background opacity"; color: panel.controller.palette.text; Layout.fillWidth: true }
                Text { text: Math.round(opacitySlider.value) + "%"; color: panel.controller.palette.muted }
            }
            SettingsSlider {
                id: opacitySlider; Layout.fillWidth: true
                from: 0; to: 100; stepSize: 1; value: panel.controller.dockStyle.opacity
                Accessible.name: "Dock background opacity"
                onMoved: panel.changeStyle({opacity: Math.round(value)})
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 10
                Rectangle {
                    width: 26; height: 26; radius: 6; color: panel.controller.dockBackgroundColor
                    border.width: 1; border.color: panel.controller.palette.muted
                }
                TextField {
                    id: backgroundField
                    property bool edited: false
                    Layout.fillWidth: true; implicitHeight: 40
                    text: panel.controller.dockBackgroundColor.toString()
                    color: panel.controller.palette.text
                    leftPadding: 12; rightPadding: 12
                    Accessible.name: "Dock background hex color"
                    validator: RegularExpressionValidator { regularExpression: /#[0-9a-fA-F]{6}/ }
                    onTextEdited: edited = true
                    onEditingFinished: {
                        if (edited && acceptableInput) panel.changeStyle({backgroundColor: text.toLowerCase()})
                        edited = false
                    }
                    background: Rectangle {
                        radius: 8; color: panel.controller.palette.surface
                        border.width: backgroundField.activeFocus ? 1 : 0; border.color: panel.controller.palette.blue
                    }
                }
                SettingsButton {
                    text: "Use desktop"; checked: panel.controller.dockStyle.backgroundColor === ""
                    onClicked: panel.changeStyle({backgroundColor: ""})
                }
            }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Text { text: "Running indicators"; color: panel.controller.palette.text; Layout.fillWidth: true }
                SettingsButton { text: "Dots"; checked: panel.controller.dockStyle.indicator === "dots"; onClicked: panel.changeStyle({indicator: "dots"}) }
                SettingsButton { text: "Rails"; checked: panel.controller.dockStyle.indicator === "rails"; onClicked: panel.changeStyle({indicator: "rails"}) }
            }
            SettingsToggle { text: "Ambient edge & active glow"; checked: panel.controller.dockStyle.ambient; onToggled: panel.changeStyle({ambient: checked}) }
            SettingsToggle { text: "Active-app spotlight"; checked: panel.controller.dockStyle.spotlight; onToggled: panel.changeStyle({spotlight: checked}) }
            SettingsToggle { text: "Show active-app name"; checked: panel.controller.dockStyle.activeLabel; onToggled: panel.changeStyle({activeLabel: checked}) }
            SettingsToggle { text: "Shelf gradient"; checked: panel.controller.dockStyle.raised; onToggled: panel.changeStyle({raised: checked}) }
            SettingsToggle { text: "Shelf drop shadow"; checked: panel.controller.dockStyle.shadow; onToggled: panel.changeStyle({shadow: checked}) }
            Text { text: "Position on screen"; color: panel.controller.palette.text }
            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Repeater {
                    model: ["Left", "Bottom", "Right", "Top"]
                    SettingsButton {
                        required property string modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 0
                        text: modelData; checkable: true; autoExclusive: true
                        checked: panel.controller.edge === modelData.toLowerCase()
                        onClicked: { panel.flush(); panel.controller.action(["position", modelData.toLowerCase()]) }
                    }
                }
            }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.fillWidth: true; spacing: 12
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
}
