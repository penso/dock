import QtQuick
import QtQuick.Controls

ToolTip {
    id: label
    property string edge: "bottom"
    delay: 0
    timeout: -1
    padding: 7
    leftPadding: 12
    rightPadding: 12
    x: edge === "left" ? parent.width + 10 : edge === "right" ? -width - 10 : (parent.width - width) / 2
    y: edge === "top" ? parent.height + 10 : edge === "bottom" ? -height - 10 : (parent.height - height) / 2
    contentItem: Text {
        text: label.text
        font.pixelSize: 12
        color: "#24252a"
    }
    background: Rectangle {
        color: "#e6d7d7dc"
        radius: height / 2
        border.width: 0.7
        border.color: "#70ffffff"
    }
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 80 } }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 60 } }
}
