import QtQuick
import QtQuick.Controls

MenuSeparator {
    id: separator
    leftPadding: 10; rightPadding: 10
    topPadding: 3; bottomPadding: 3
    contentItem: Rectangle {
        implicitWidth: 170; implicitHeight: 1
        color: separator.palette.mid
    }
}
