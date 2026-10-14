import QtQuick

Item {
    id: indicators
    property var activity: ({})
    property bool urgent: false
    readonly property bool showCount: activity.countVisible === true && Number(activity.count) > 0
    readonly property string countText: Number(activity.count) > 99 ? "99+" : String(Math.floor(Number(activity.count) || 0))
    readonly property real progress: Math.max(0, Math.min(1, Number(activity.progress) || 0))

    Rectangle {
        objectName: "dock-attention-ring"
        anchors.fill: parent
        anchors.margins: -2
        visible: indicators.urgent
        color: "transparent"
        border.color: "#e0af68"
        border.width: 2
        radius: parent.width * 0.225 + 2
    }
    Rectangle {
        id: badge
        objectName: "dock-count-badge"
        visible: indicators.showCount
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -4
        anchors.topMargin: -4
        height: Math.max(16, Math.min(24, parent.width * 0.36))
        width: Math.max(height, countLabel.implicitWidth + 9)
        radius: height / 2
        color: "#e5484d"
        border.width: 1
        border.color: "#55ffffff"
        Text {
            id: countLabel
            anchors.centerIn: parent
            text: indicators.countText
            color: "white"
            font.pixelSize: Math.max(10, badge.height * 0.62)
            font.weight: Font.DemiBold
        }
    }
    Rectangle {
        objectName: "dock-attention-dot"
        visible: indicators.urgent && !indicators.showCount
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: -2
        width: Math.max(10, Math.min(14, parent.width * 0.25))
        height: width
        radius: width / 2
        color: "#e0af68"
        border.width: 1
        border.color: "#55302010"
    }
    Rectangle {
        id: track
        objectName: "dock-progress-track"
        visible: indicators.activity.progressVisible === true
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Math.max(3, parent.width * 0.09)
        height: Math.max(3, Math.min(5, parent.height * 0.08))
        radius: height / 2
        color: "#cc151722"
        Rectangle {
            objectName: "dock-progress-fill"
            width: parent.width * indicators.progress
            height: parent.height
            radius: parent.radius
            color: "#7aa2f7"
            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }
    }
}
