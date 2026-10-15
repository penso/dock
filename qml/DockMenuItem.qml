import QtQuick
import QtQuick.Controls

MenuItem {
    id: control
    property string glyph: ""
    implicitHeight: 26
    implicitWidth: 198
    leftPadding: checkable ? 24 : 10
    rightPadding: 22
    font.family: "Noto Sans"
    font.pixelSize: 13
    contentItem: Text {
        text: control.text
        font: control.font
        color: control.highlighted ? control.palette.highlightedText : control.palette.text
        opacity: control.enabled ? 1 : 0.4
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: Text {
        x: 9; y: (control.height - height) / 2
        width: 16
        text: control.checkable && control.checked ? "✓" : ""
        color: control.highlighted ? control.palette.highlightedText : control.palette.text
        opacity: control.enabled ? 0.8 : 0.35
        font.pixelSize: 14
        horizontalAlignment: Text.AlignHCenter
    }
    arrow: Text {
        x: control.width - width - 10; y: (control.height - height) / 2
        width: 14
        visible: !!control.subMenu
        text: "›"; font.pixelSize: 22
        color: control.highlighted ? control.palette.highlightedText : control.palette.text; opacity: 0.8
        horizontalAlignment: Text.AlignHCenter
    }
    background: Rectangle {
        radius: 5
        color: control.highlighted ? control.palette.highlight : "transparent"
        Behavior on color { ColorAnimation { duration: 90 } }
    }
}
