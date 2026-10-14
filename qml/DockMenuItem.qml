import QtQuick
import QtQuick.Controls

MenuItem {
    id: control
    property string glyph: ""
    implicitHeight: 34
    implicitWidth: 260
    leftPadding: 30
    rightPadding: 28
    font.pixelSize: 13
    contentItem: Text {
        text: control.text
        font: control.font
        color: control.palette.text
        opacity: control.enabled ? 1 : 0.4
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: Text {
        x: 9; y: (control.height - height) / 2
        width: 16
        text: control.checkable ? (control.checked ? "✓" : "") : control.glyph
        color: control.palette.text
        opacity: control.enabled ? 0.8 : 0.35
        font.pixelSize: 14
        horizontalAlignment: Text.AlignHCenter
    }
    arrow: Text {
        x: control.width - width - 10; y: (control.height - height) / 2
        width: 14
        visible: !!control.subMenu
        text: "›"; font.pixelSize: 22
        color: control.palette.text; opacity: 0.65
        horizontalAlignment: Text.AlignHCenter
    }
    background: Rectangle {
        radius: 8
        color: control.highlighted ? control.palette.highlight : "transparent"
        Behavior on color { ColorAnimation { duration: 90 } }
    }
}
