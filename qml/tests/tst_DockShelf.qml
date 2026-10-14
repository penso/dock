import QtQuick
import QtTest
import ".." as Dock

Item {
    id: scene
    width: 700; height: 500
    QtObject {
        id: controller
        property bool vertical: false
        property string edge: "bottom"
        property bool appsOpen: false
        property var launches: ({})
        property var lastAction: []
        property bool resizingDock: false
        property int dockSize: 40
        property int dockMagnification: 132
        property var items: [
            {key: "a", pinned: true, windows: []},
            {key: "b", pinned: true, windows: [{activated: true}]},
            {key: "c", pinned: false, windows: [{activated: false}]}
        ]
        property var palette: ({base: "#202030", text: "#ffffff", surface: "#303044"})
        function alpha(value, opacity) { var c = Qt.color(value); return Qt.rgba(c.r, c.g, c.b, opacity) }
        function icon(key) { return "" }
        function name(key) { return key }
        function action(args) { lastAction = args }
        function launch(key) { lastAction = ["launch", key] }
        function activate(item) { lastAction = ["activate", item.key] }
        function previewAppearance(size, magnification) {
            dockSize = size; dockMagnification = magnification
            shelf.iconSize = size
        }
        function saveAppearance() { lastAction = ["appearance", String(dockSize), String(dockMagnification)] }
    }
    QtObject {
        id: host
        property bool expanded: true
        property bool dragging: false
        property int width: 640
        property int height: 300
        property string previewKey: ""
        property var previewAnchor: null
        function keepPreview() {}
        function dismissPreview() {}
    }
    Dock.DockShelf {
        id: shelf; controller: controller; host: host
        x: controller.vertical ? (controller.edge === "right" ? host.width - width : 0) : (host.width - width) / 2 + axisOffset
        y: controller.vertical ? (host.height - height) / 2 + axisOffset : (controller.edge === "bottom" ? host.height - height : 0)
    }
    TestCase {
        name: "DockShelf"
        when: windowShown
        function init() {
            shelf.finishResize(false)
            controller.dockSize = 40; controller.dockMagnification = 132
            shelf.iconSize = 40; shelf.maximumMagnification = 1.32
            controller.vertical = false; controller.edge = "bottom"
            controller.lastAction = []; host.previewKey = ""
            shelf.finishDrag(false)
            mouseMove(shelf, 600, 200)
            wait(250)
        }
        function test_neighbourLens() {
            mouseMove(shelf, 105, 82)
            wait(220)
            verify(shelf.placement("a").scale > 1.25)
            verify(shelf.placement("b").scale > 1)
            verify(shelf.placement("a").scale > shelf.placement("b").scale)
            mouseMove(shelf, 600, 200)
            tryCompare(shelf, "lensAmount", 0)
            fuzzyCompare(shelf.placement("a").scale, 1, 0.001)
        }
        function test_clickActivation() {
            mouseClick(shelf, 157, 82)
            compare(controller.lastAction[0], "activate")
            compare(controller.lastAction[1], "b")
        }
        function test_dragRunningIntoPins() {
            var pos = shelf.placement("c")
            mousePress(shelf, pos.position + pos.extent / 2, 82)
            mouseMove(shelf, 100, 82, 80)
            wait(220)
            verify(shelf.dragging)
            compare(shelf.order[0], "c")
            mouseRelease(shelf, 100, 82)
            compare(controller.lastAction[0], "pin-at")
            compare(controller.lastAction[1], "c")
            compare(controller.lastAction[2], "0")
            verify(!host.dragging)
        }
        function test_verticalLens() {
            controller.vertical = true; controller.edge = "right"
            wait(200)
            mouseMove(shelf, 82, 105)
            wait(220)
            verify(shelf.placement("a").scale > 1.25)
            verify(shelf.placement("b").scale > 1)
        }
        function test_stationaryHoverSettles() {
            mouseMove(shelf, 105, 82)
            wait(350)
            var length = shelf.naturalLength
            var peak = shelf.placement("a").scale
            wait(400)
            fuzzyCompare(shelf.naturalLength, length, 0.1)
            fuzzyCompare(shelf.placement("a").scale, peak, 0.001)
        }
        function test_waveTracksAcrossSeparator() {
            mouseMove(shelf, 95, 82)
            wait(300)
            var previous = shelf.pointer
            var gap = shelf.placement("c").position - 8
            mouseMove(shelf, gap, 82)
            wait(150)
            verify(shelf.pointer > previous + 40)
            verify(shelf.lensPointer > previous + 30)
            verify(shelf.placement("b").scale > 1)
            verify(shelf.placement("c").scale > 1)
        }
        function test_sizeAndMagnification() {
            shelf.iconSize = 72; shelf.maximumMagnification = 2
            wait(100)
            fuzzyCompare(shelf.depth, 230.4, 0.001)
            fuzzyCompare(shelf.cell, 93.6, 0.001)
            var pos = shelf.placement("a")
            mouseMove(shelf, pos.position + pos.extent / 2, 82 * shelf.unit)
            wait(400)
            verify(shelf.placement("a").scale > 1.9)
            shelf.maximumMagnification = 1
            compare(shelf.placement("a").scale, 1)
            shelf.iconSize = 24
            fuzzyCompare(shelf.depth, 76.8, 0.001)
        }
        function test_resizeKeepsGlassAtSelectedEdge() {
            var glass = findChild(shelf, "dock-glass")
            verify(glass !== null)
            for (var edge of ["bottom", "left", "right", "top"]) {
                controller.edge = edge
                controller.vertical = edge === "left" || edge === "right"
                for (var size = 24; size <= 72; size += 2) {
                    shelf.iconSize = size
                    var gap = edge === "bottom" ? host.height - shelf.y - glass.y - glass.height
                        : edge === "right" ? host.width - shelf.x - glass.x - glass.width
                        : edge === "left" ? shelf.x + glass.x : shelf.y + glass.y
                    fuzzyCompare(gap, 8, 0.001)
                    if (controller.vertical) fuzzyCompare(shelf.y + shelf.height / 2, host.height / 2 + shelf.axisOffset, 0.001)
                    else fuzzyCompare(shelf.x + shelf.width / 2, host.width / 2 + shelf.axisOffset, 0.001)
                }
            }
        }
        function test_launchBounceStopsWhenWindowArrives() {
            var slot = findChild(shelf, "dock-slot-a")
            verify(slot !== null)
            controller.launches = {a: {count: 0}}
            wait(150)
            verify(slot.bounce > 0)
            controller.launches = {}
            wait(50)
            compare(slot.bounce, 0)
        }
        function test_emptySpaceDoesNotMagnify() {
            mouseMove(shelf, 105, 10)
            wait(200)
            compare(shelf.magnify, false)
            fuzzyCompare(shelf.lensAmount, 0, 0.001)
            mouseMove(shelf, 105, 82)
            wait(200)
            verify(shelf.magnify)
            verify(shelf.lensAmount > 0.99)
        }
        function test_leaveContractsInPlace() {
            mouseMove(shelf, 105, 82)
            wait(250)
            var center = shelf.lensPointer
            mouseMove(shelf, 600, 10)
            wait(250)
            fuzzyCompare(shelf.lensPointer, center, 0.1)
            verify(shelf.lensAmount < 0.005)
            verify(!shelf.magnify)
        }
        function test_labelsStayReadyBetweenIconsAndResetOnExit() {
            mouseMove(shelf, 105, 82)
            wait(250)
            verify(shelf.labelReady)
            mouseMove(shelf, 165, 82)
            verify(shelf.labelReady)
            mouseMove(shelf, 600, 10)
            tryCompare(shelf, "labelReady", false)
        }
        function test_dividerDragResizesLiveAndSavesOnRelease() {
            var grip = findChild(shelf, "dock-resize-grip")
            verify(grip !== null)
            var start = grip.mapToItem(scene, grip.width / 2, grip.height / 2)
            mousePress(scene, start.x, start.y)
            verify(shelf.resizing)
            verify(host.dragging)
            verify(controller.resizingDock)
            mouseMove(scene, start.x, start.y - 20, 30)
            tryCompare(controller, "dockSize", 60)
            compare(shelf.iconSize, 60)
            compare(controller.lastAction.length, 0)
            verify(!shelf.magnify)
            wait(300)
            compare(controller.dockSize, 60) // Resizing geometry must not feed back into pointer delta.
            mouseRelease(scene, start.x, start.y - 20)
            compare(controller.lastAction.join(","), "appearance,60,132")
            verify(!shelf.resizing)
            verify(!host.dragging)
            verify(!controller.resizingDock)
        }
        function test_dividerDirectionsBoundsAndCancel() {
            for (var edge of ["bottom", "top", "left", "right"]) {
                controller.edge = edge
                controller.vertical = edge === "left" || edge === "right"
                controller.previewAppearance(40, 175)
                controller.lastAction = []
                shelf.startResize(100)
                var direction = edge === "bottom" || edge === "right" ? -1 : 1
                shelf.updateResize(100 + direction * 15)
                compare(controller.dockSize, 55)
                compare(controller.dockMagnification, 175)
                shelf.updateResize(100 + direction * 500)
                compare(controller.dockSize, 72)
                shelf.updateResize(100 - direction * 500)
                compare(controller.dockSize, 24)
                shelf.finishResize(false)
                compare(controller.dockSize, 40)
                compare(controller.lastAction.length, 0)
            }
        }
    }
}
