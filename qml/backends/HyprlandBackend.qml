import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import "../DockModel.js" as DockModel

Item {
    id: backend
    property var controller
    readonly property string name: "hyprland"
    readonly property var capabilities: ({ workspaces: true, overlap: true, urgentWindows: true, minimize: true })
    property var clients: []
    property var urgentWindows: ({})
    readonly property var focusedScreen: Hyprland.focusedMonitor
        ? Quickshell.screens.find(function(screen) { return screen.name === Hyprland.focusedMonitor.name })
        : Quickshell.screens[0]
    readonly property int activeWorkspace: Hyprland.focusedMonitor && Hyprland.focusedMonitor.activeWorkspace
        ? Hyprland.focusedMonitor.activeWorkspace.id : -1
    readonly property var windows: {
        var result = []
        var all = Hyprland.toplevels.values
        for (var i = 0; i < all.length; i++) {
            var window = all[i]
            var wl = window.wayland
            var appId = wl ? wl.appId : (window.lastIpcObject["class"] || "")
            if (!appId || (wl && wl.parent)) continue
            var workspace = window.workspace
            result.push({ appId: appId, wayland: wl, address: window.address,
                title: window.title, activated: window.activated,
                urgent: window.urgent === true || urgentWindows[DockModel.windowAddress(window.address)] === true,
                workspaceId: workspace ? workspace.id : -1,
                minimized: !!workspace && DockModel.isMinimizedWorkspace(workspace.name) })
        }
        return result
    }
    function address(window) { return "0x" + DockModel.windowAddress(window.address) }
    function activate(window) { if (controller && window) controller.action(["focus", address(window)]) }
    function close(window) { if (controller && window) controller.action(["close", address(window)]) }
    function minimizeActive() { if (controller) controller.action(["minimize"]) }
    function minimize(window) { if (controller && window) controller.action(["minimize", address(window)]) }
    function restore() { if (controller) controller.action(["restore"]) }
    function monitorFor(screen) { return Hyprland.monitorFor(screen) }
    function workspaceFor(monitor) {
        return monitor && monitor.activeWorkspace ? monitor.activeWorkspace.id : -1
    }
    function topMargin(monitor) {
        return monitor && monitor.lastIpcObject.reserved ? monitor.lastIpcObject.reserved[1] : 0
    }
    function overlaps(workspace, rect) {
        return clients.some(function(client) {
            if (!client.mapped || client.hidden || !client.workspace || (client.workspace.id !== workspace && !client.pinned)) return false
            return client.at[0] < rect.x + rect.width && client.at[0] + client.size[0] > rect.x
                && client.at[1] < rect.y + rect.height && client.at[1] + client.size[1] > rect.y
        })
    }
    Process {
        id: geometryPoll
        command: [Quickshell.env("DOCK_HYPRCTL") || "hyprctl", "clients", "-j"]
        stdout: StdioCollector { onStreamFinished: { try { backend.clients = JSON.parse(text) } catch (error) {} } }
    }
    Timer {
        interval: 400; repeat: true; triggeredOnStart: true
        running: !!backend.controller && backend.controller.settings.dock.intellihide !== false
        onTriggered: if (!geometryPoll.running) geometryPoll.running = true
    }
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (["urgent", "activewindowv2", "closewindow"].indexOf(event.name) >= 0)
                backend.urgentWindows = DockModel.urgencyEvent(backend.urgentWindows, event.name, event.data)
            if (["configreloaded", "fullscreen", "movewindowv2"].indexOf(event.name) >= 0) {
                Hyprland.refreshToplevels()
                Hyprland.refreshWorkspaces()
            }
        }
    }
}
