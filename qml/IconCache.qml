import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: cache
    required property string helper
    required property var controller
    // Use the window's fractional scale, not QScreen's rounded scale.
    property real displayScale: Screen.devicePixelRatio
    property var entries: ({})
    readonly property bool active: Quickshell.env("DOCK_ICON_FILTER") !== "native"
    readonly property bool building: worker.running
    property real startedAt: 0
    property real elapsedMs: 0
    readonly property var summary: ({filter: active ? "lanczos-atlas" : "native", cached: Object.keys(entries).length, scale: displayScale, building: building, elapsedMs: elapsedMs})
    property string submitted: ""
    readonly property string request: JSON.stringify({
        size: controller.dockSize,
        magnification: controller.dockMagnification / 100,
        scale: displayScale,
        sources: controller.items.map(function(item) { return controller.icon(item.key).toString() })
    })
    onRequestChanged: debounce.restart()
    Component.onCompleted: debounce.restart()
    Timer {
        id: debounce; interval: 180
        onTriggered: {
            if (!cache.active || worker.running || cache.submitted === cache.request) return
            cache.submitted = cache.request
            cache.startedAt = Date.now()
            worker.command = [Quickshell.env("DOCK_ICON_PYTHON") || "/usr/bin/python3", cache.helper, cache.submitted]
            worker.running = true
        }
    }
    Process {
        id: worker
        stdout: StdioCollector {
            onStreamFinished: {
                try { cache.entries = JSON.parse(text) }
                catch (error) { console.warn("Dock icon cache:", error) }
            }
        }
        stderr: SplitParser { onRead: function(line) { console.warn(line) } }
        onExited: {
            cache.elapsedMs = Date.now() - cache.startedAt
            if (cache.submitted !== cache.request) debounce.restart()
        }
    }
}
