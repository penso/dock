import QtQuick
import QtQuick.Controls

Menu {
    id: menu
    required property var colors
    property var anchorItem: null
    property var boundsItem: null
    property string edge: "bottom"
    property bool pointed: false
    property real preferredWidth: 208
    readonly property var anchorPoint: {
        if (!anchorItem || !boundsItem) return Qt.point(0, 0)
        var changedGeometry = anchorItem.x + anchorItem.y + anchorItem.width + anchorItem.height
        return anchorItem.mapToItem(boundsItem, 0, 0)
    }
    function popupFor(item, dockEdge, bounds) {
        anchorItem = item
        boundsItem = bounds
        edge = dockEdge
        parent = item
        pointed = true
        open()
    }
    Binding {
        target: menu; property: "x"; when: menu.pointed && !!menu.anchorItem
        value: !menu.anchorItem ? 0 : menu.edge === "left" ? menu.anchorItem.width + 14 : menu.edge === "right" ? -menu.width - 14
            : Math.max(12 - menu.anchorPoint.x, Math.min((menu.boundsItem ? menu.boundsItem.width : 10000) - 12 - menu.anchorPoint.x - menu.width, menu.anchorItem.width / 2 - 28))
    }
    Binding {
        target: menu; property: "y"; when: menu.pointed && !!menu.anchorItem
        value: !menu.anchorItem ? 0 : menu.edge === "bottom" ? -menu.height - 14 : menu.edge === "top" ? menu.anchorItem.height + 14
            : Math.max(12 - menu.anchorPoint.y, Math.min((menu.boundsItem ? menu.boundsItem.height : 10000) - 12 - menu.anchorPoint.y - menu.height, menu.anchorItem.height / 2 - 28))
    }
    popupType: Popup.Window
    width: preferredWidth
    padding: 5
    margins: 12
    topInset: -12 - (pointed && edge === "top" ? 8 : 0)
    bottomInset: -12 - (pointed && edge === "bottom" ? 8 : 0)
    leftInset: -12 - (pointed && edge === "left" ? 8 : 0)
    rightInset: -12 - (pointed && edge === "right" ? 8 : 0)
    font.family: "Noto Sans"
    font.pixelSize: 13
    palette.window: "#c5c5ca"
    palette.text: "#202124"
    palette.buttonText: "#202124"
    palette.highlightedText: "white"
    palette.highlight: "#3478f6"
    palette.mid: "#30000000"
    delegate: DockMenuItem {}
    background: MenuBubble {
        pointed: menu.pointed
        edge: menu.edge
        tailPosition: menu.anchorItem ? ((menu.edge === "bottom" || menu.edge === "top")
            ? menu.anchorItem.width / 2 - menu.x : menu.anchorItem.height / 2 - menu.y) : 28
    }
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 110; easing.type: Easing.OutCubic } }
    exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 80 } }
}
