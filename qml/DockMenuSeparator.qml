import QtQuick
import QtQuick.Controls

MenuSeparator {
    id: separator
    leftPadding: 10; rightPadding: 10
    topPadding: 6; bottomPadding: 6
    contentItem: Rectangle {
        implicitWidth: 240; implicitHeight: 1
        color: separator.palette.mid
    }
}
