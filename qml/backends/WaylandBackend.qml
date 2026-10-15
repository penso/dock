import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
    id: backend
    property var controller
    readonly property string name: "wayland"
    // Foreign-toplevel does not expose workspaces, rectangles, or urgency.
    readonly property var capabilities: ({ workspaces: false, overlap: false, urgentWindows: false, minimize: true })
    readonly property int activeWorkspace: 1
    readonly property var focusedScreen: ToplevelManager.activeToplevel && ToplevelManager.activeToplevel.screens.length
        ? ToplevelManager.activeToplevel.screens[0] : Quickshell.screens[0]
    readonly property var windows: {
        var result = []
        var all = ToplevelManager.toplevels.values
        for (var i = 0; i < all.length; i++) {
            var window = all[i]
            if (!window.appId || window.parent) continue
            result.push({ appId: window.appId, wayland: window, title: window.title,
                activated: window.activated, minimized: window.minimized,
                urgent: false, workspaceId: 1 })
        }
        return result
    }
    function activate(window) {
        if (!window || !window.wayland) return
        window.wayland.minimized = false
        window.wayland.activate()
    }
    function close(window) { if (window && window.wayland) window.wayland.close() }
    function minimizeActive() {
        if (ToplevelManager.activeToplevel) ToplevelManager.activeToplevel.minimized = true
    }
    function minimize(window) { if (window && window.wayland) window.wayland.minimized = true }
    function restore() {
        var window = windows.find(function(item) { return item.minimized })
        if (window) activate(window)
    }
    function monitorFor(screen) { return screen }
    function workspaceFor(screen) { return 1 }
    function topMargin(screen) { return 0 }
    function overlaps(workspace, rect) { return false }
}
