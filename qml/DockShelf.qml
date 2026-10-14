import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "DockModel.js" as DockModel

Item {
    id: shelf
    required property var controller
    required property var host
    signal launcherMenu()
    signal appMenu(var item)
    readonly property bool vertical: controller.vertical
    readonly property string edge: controller.edge
    property real iconSize: 40
    property real maximumMagnification: 1.32
    readonly property real unit: iconSize / 40
    readonly property real depth: 128 * unit
    readonly property real edgeGap: 8
    readonly property real iconBaseline: depth - edgeGap - 16 * unit
    readonly property real iconStart: edgeGap + 16 * unit
    readonly property real cell: 52 * unit
    property var keys: []
    property string dragKey: ""
    property int dragIndex: -1
    property real dragPosition: 0
    property real pointer: 0
    property real lensPointer: 0
    property real lensVelocity: 0
    property real lensAmount: 0
    property real amountVelocity: 0
    readonly property bool dragging: dragKey !== ""
    readonly property int pinCount: controller.items.filter(function(i) { return i.pinned }).length
    readonly property bool divided: pinCount > 0 && pinCount < keys.length
    readonly property var order: dragging ? DockModel.dragOrder(keys, dragKey, dragIndex) : keys
    readonly property real baseLength: (keys.length + 1) * cell + (divided ? 16 * unit : 0) + 20 * unit
    readonly property bool magnify: shelfHover.hovered && inHoverZone && !dragging && host.expanded
    readonly property bool inHoverZone: {
        var p = shelfHover.point.position
        return p.x >= x && p.x <= x + width && p.y >= y && p.y <= y + height
    }
    FrameAnimation {
        running: Math.abs(shelf.lensAmount - (shelf.magnify ? 1 : 0)) > 0.0001
            || Math.abs(shelf.amountVelocity) > 0.002
            || (shelf.magnify && (Math.abs(shelf.lensPointer - shelf.pointer) > 0.02 || Math.abs(shelf.lensVelocity) > 0.05))
        onTriggered: {
            var dt = Math.max(0.001, frameTime)
            var center = DockModel.springStep(shelf.lensPointer, shelf.lensVelocity, shelf.pointer, dt, 42)
            var amount = DockModel.springStep(shelf.lensAmount, shelf.amountVelocity, shelf.magnify ? 1 : 0, dt, 30)
            shelf.lensPointer = center.position; shelf.lensVelocity = center.velocity
            shelf.lensAmount = amount.position; shelf.amountVelocity = amount.velocity
            if (Math.abs(shelf.lensAmount - (shelf.magnify ? 1 : 0)) < 0.0001 && Math.abs(shelf.amountVelocity) < 0.002) {
                shelf.lensAmount = shelf.magnify ? 1 : 0; shelf.amountVelocity = 0
            }
        }
    }
    readonly property var layout: {
        var result = []; var position = 10 * unit
        for (var i = -1; i < order.length; i++) {
            if (divided && i === pinCount) position += 16 * unit
            var base = 10 * unit + (i + 1.5) * cell + (divided && i >= pinCount ? 16 * unit : 0)
            var scale = 1 + lensAmount * (DockModel.magnification(base - lensPointer, cell * 3, maximumMagnification) - 1)
            var extent = cell + (scale - 1) * iconSize
            result.push({ key: i < 0 ? "" : order[i], position: position, extent: extent, scale: scale })
            position += extent
        }
        return result
    }
    readonly property real naturalLength: layout.length ? layout[layout.length - 1].position + layout[layout.length - 1].extent + 10 * unit : 72 * unit
    readonly property real visibleLength: Math.min(naturalLength, vertical ? host.height : host.width)
    width: vertical ? depth : visibleLength
    height: vertical ? visibleLength : depth

    function appFor(key) { return controller.items.find(function(i) { return i.key === key }) }
    function tileColor(key) {
        if (key === "google-chrome") return "#fafafa"
        if (key === "org.gnome.Nautilus") return "#418dcc"
        if (key.indexOf("ghostty") >= 0) return "#253c5c"
        return "#30343c"
    }
    function placement(key) { return layout.find(function(i) { return i.key === key }) || { position: 0, extent: cell, scale: 1 } }
    function syncKeys() {
        if (dragging) return
        var pins = controller.items.filter(function(i) { return i.pinned })
        var running = DockModel.orderItems(controller.items.filter(function(i) { return !i.pinned }), keys)
        var next = pins.concat(running).map(function(i) { return i.key })
        if (JSON.stringify(next) !== JSON.stringify(keys)) keys = next
    }
    function trackPointer() {
        var p = shelfHover.point.position
        // Do not consult a derived hover binding in this signal handler: Qt
        // may notify the point before reevaluating that binding.
        if (p.x < x || p.x > x + width || p.y < y || p.y > y + height) return
        // Read from the fixed panel, never an animated icon or its hit area.
        var axis = vertical ? p.y - y : p.x - x
        pointer = axis + (baseLength - visibleLength) / 2 + (vertical ? viewport.contentY : viewport.contentX)
        if (lensAmount < 0.001) { lensPointer = pointer; lensVelocity = 0 }
    }
    function finishDrag(commit) {
        if (!dragging) return
        var item = appFor(dragKey)
        if (commit && item && (item.pinned || dragIndex <= pinCount)) {
            controller.action(["pin-at", dragKey, String(Math.min(dragIndex, item.pinned ? Math.max(0, pinCount - 1) : pinCount))])
        }
        if (commit) keys = order.slice()
        dragKey = ""; dragIndex = -1; syncKeys()
    }
    Component.onCompleted: syncKeys()
    Connections { target: controller; function onItemsChanged() { shelf.syncKeys() } }
    onDraggingChanged: host.dragging = dragging
    Component.onDestruction: host.dragging = false

    // Retain the last pointer position on exit: fade the entire wave out rather
    // than sweeping it across the icons towards an offscreen sentinel.
    HoverHandler {
        id: shelfHover
        parent: shelf.parent
        onPointChanged: shelf.trackPointer()
        onHoveredChanged: if (hovered) shelf.trackPointer()
    }
    Rectangle {
        id: glass
        objectName: "dock-glass"
        x: vertical ? (edge === "right" ? shelf.depth - shelf.edgeGap - width : shelf.edgeGap) : 0
        y: vertical ? 0 : (edge === "bottom" ? shelf.depth - shelf.edgeGap - height : shelf.edgeGap)
        width: vertical ? 64 * unit : shelf.width
        height: vertical ? shelf.height : 64 * unit
        radius: 17 * unit
        color: "#a64b4d52"
        border.width: 0.7
        border.color: "#38ffffff"
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#40000000"; shadowBlur: 0.4; shadowVerticalOffset: 2 }
        Rectangle {
            anchors.fill: parent; anchors.margins: 1; radius: 17 * shelf.unit - 1; color: "transparent"
            border.width: 0.7; border.color: "#16000000"
        }
    }
    Flickable {
        id: viewport
        anchors.fill: parent
        contentWidth: vertical ? width : shelf.naturalLength
        contentHeight: vertical ? shelf.naturalLength : height
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        onMovementStarted: host.previewKey = ""
        flickableDirection: vertical ? Flickable.VerticalFlick : Flickable.HorizontalFlick
        Rectangle {
            visible: shelf.divided
            readonly property real position: shelf.placement(shelf.order[shelf.pinCount]).position - 8 * unit
            x: vertical ? glass.x + (glass.width - width) / 2 : position
            y: vertical ? position : glass.y + (glass.height - height) / 2
            width: vertical ? 34 * unit : 1; height: vertical ? 1 : 34 * unit
            color: controller.alpha(controller.palette.text, 0.22)
            Behavior on x { enabled: shelf.dragging; NumberAnimation { duration: 180 } }
            Behavior on y { enabled: shelf.dragging; NumberAnimation { duration: 180 } }
        }
        Item {
            id: launcherSlot
            readonly property var place: shelf.placement("")
            x: vertical ? 0 : place.position; y: vertical ? place.position : 0
            width: vertical ? depth : place.extent; height: vertical ? place.extent : depth
            AppTile {
                launcher: true
                width: shelf.iconSize * launcherSlot.place.scale; height: width
                x: vertical ? (edge === "right" ? shelf.iconBaseline - width : shelf.iconStart) : (parent.width - width) / 2
                y: vertical ? (parent.height - height) / 2 : (edge === "bottom" ? shelf.iconBaseline - height : shelf.iconStart)
            }
            ToolTip.visible: launcherMouse.containsMouse && !shelf.dragging
            ToolTip.delay: 600; ToolTip.text: "Applications · right-click for dock settings"
            MouseArea {
                id: launcherMouse; anchors.fill: parent; hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: function(mouse) { if (mouse.button === Qt.RightButton) shelf.launcherMenu(); else controller.appsOpen = !controller.appsOpen }
            }
        }
        Repeater {
            model: shelf.keys
            delegate: Item {
                id: slot
                required property string modelData
                objectName: "dock-slot-" + modelData
                readonly property var app: shelf.appFor(modelData)
                readonly property var place: shelf.placement(modelData)
                readonly property bool lifted: shelf.dragKey === modelData
                readonly property bool active: !!app && app.windows.some(function(w) { return w.activated })
                readonly property bool launching: !!controller.launches[modelData]
                property real bounce: 0
                readonly property real axis: lifted ? shelf.dragPosition - place.extent / 2 : place.position
                x: vertical ? 0 : axis; y: vertical ? axis : 0
                width: vertical ? depth : place.extent; height: vertical ? place.extent : depth
                z: lifted ? 10 : 1
                Behavior on x { enabled: shelf.dragging && !slot.lifted; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                Behavior on y { enabled: shelf.dragging && !slot.lifted; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                AppTile {
                    id: icon
                    property real pressScale: mouse.pressed && !slot.lifted ? 0.94 : 1
                    property real liftScale: slot.lifted ? 1.14 : 1
                    readonly property real iconSize: shelf.iconSize * slot.place.scale * pressScale * liftScale
                    Behavior on pressScale { NumberAnimation { duration: 110 } }
                    Behavior on liftScale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                    width: iconSize; height: iconSize
                    x: vertical ? (edge === "right" ? shelf.iconBaseline - width - slot.bounce : shelf.iconStart + slot.bounce) : (parent.width - width) / 2
                    y: vertical ? (parent.height - height) / 2 : (edge === "bottom" ? shelf.iconBaseline - height - slot.bounce : shelf.iconStart + slot.bounce)
                    source: controller.icon(slot.modelData)
                    tileColor: shelf.tileColor(slot.modelData)
                    layer.enabled: slot.lifted
                    layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: 0.4; shadowVerticalOffset: 5; shadowColor: "#80000000" }
                }
                Rectangle {
                    visible: !!slot.app && slot.app.windows.length > 0
                    x: vertical ? (edge === "right" ? shelf.depth - shelf.edgeGap - 9 * unit : shelf.edgeGap + 5 * unit) : (parent.width - width) / 2
                    y: vertical ? (parent.height - height) / 2 : (edge === "bottom" ? shelf.depth - shelf.edgeGap - 9 * unit : shelf.edgeGap + 5 * unit)
                    width: 4 * unit; height: width; radius: width / 2
                    color: slot.active ? "#f2f2f4" : "#adbec0c5"
                }
                SequentialAnimation {
                    id: launchBounce; running: slot.launching && host.expanded; loops: 3
                    NumberAnimation { target: slot; property: "bounce"; to: 15 * shelf.unit; duration: 240; easing.type: Easing.OutQuad }
                    NumberAnimation { target: slot; property: "bounce"; to: 0; duration: 320; easing.type: Easing.OutBounce }
                    PauseAnimation { duration: 220 }
                    onStopped: slot.bounce = 0
                }
                ToolTip.visible: mouse.containsMouse && !!slot.app && !slot.app.windows.length && !shelf.dragging
                ToolTip.delay: 500; ToolTip.text: controller.name(slot.modelData)
                Timer {
                    id: previewDelay; interval: host.previewKey ? 110 : 450
                    onTriggered: if (mouse.containsMouse && slot.app && slot.app.windows.length && !shelf.dragging) {
                        host.previewAnchor = slot; host.previewKey = slot.modelData
                    }
                }
                MouseArea {
                    id: mouse; anchors.fill: parent; hoverEnabled: true; preventStealing: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    property real pressAxis: 0
                    property bool wasDragged: false
                    onEntered: { host.keepPreview(); previewDelay.restart() }
                    onExited: { previewDelay.stop(); host.dismissPreview() }
                    onPressed: function(event) {
                        var point = mapToItem(viewport.contentItem, event.x, event.y)
                        pressAxis = vertical ? point.y : point.x; wasDragged = false
                    }
                    onPositionChanged: function(event) {
                        if (!(pressedButtons & Qt.LeftButton)) return
                        var point = mapToItem(viewport.contentItem, event.x, event.y)
                        var axis = vertical ? point.y : point.x
                        if (!wasDragged && Math.abs(axis - pressAxis) < 8) return
                        wasDragged = true; previewDelay.stop(); host.previewKey = ""
                        shelf.dragKey = slot.modelData
                        shelf.dragPosition = Math.max(62 * unit, Math.min(shelf.naturalLength - 26 * unit, axis))
                        var normalized = axis - 10 * unit - shelf.cell - (shelf.divided && axis > (shelf.pinCount + 1) * shelf.cell + 10 * unit ? 16 * unit : 0)
                        shelf.dragIndex = Math.max(0, Math.min(shelf.keys.length - 1, Math.floor(normalized / shelf.cell)))
                    }
                    onReleased: shelf.finishDrag(true)
                    onCanceled: shelf.finishDrag(false)
                    onClicked: function(event) {
                        if (wasDragged || !slot.app) return
                        host.previewKey = ""
                        if (event.button === Qt.RightButton) shelf.appMenu(slot.app)
                        else if (event.button === Qt.MiddleButton) controller.launch(slot.modelData)
                        else controller.activate(slot.app)
                    }
                }
            }
        }
        ScrollBar.horizontal: ScrollBar { policy: !vertical && shelf.naturalLength > shelf.width ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }
        ScrollBar.vertical: ScrollBar { policy: vertical && shelf.naturalLength > shelf.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }
    }
}
