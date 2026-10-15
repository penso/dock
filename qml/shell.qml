import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "DockModel.js" as DockModel

ShellRoot {
    id: root
    readonly property string home: Quickshell.env("HOME")
    readonly property string configDir: Quickshell.env("DOCK_CONFIG_DIR") || ((Quickshell.env("XDG_CONFIG_HOME") || home + "/.config") + "/dock")
    readonly property string helper: Quickshell.env("DOCK_HELPER") || decodeURIComponent(Qt.resolvedUrl("../bin/dockctl").toString().replace(/^file:\/\//, ""))
    readonly property string compositorChoice: Quickshell.env("DOCK_COMPOSITOR") || "auto"
    property bool hyprlandUnavailable: false
    readonly property bool useHyprland: !hyprlandUnavailable && (compositorChoice === "hyprland"
        || (compositorChoice === "auto" && !!Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE")))
    readonly property var backend: compositorLoader.item
    Loader {
        id: compositorLoader
        source: Qt.resolvedUrl(root.useHyprland ? "backends/HyprlandBackend.qml" : "backends/WaylandBackend.qml")
        onLoaded: item.controller = root
        onStatusChanged: if (status === Loader.Error && root.useHyprland && root.compositorChoice === "auto") {
            console.warn("Hyprland integration unavailable; using the generic Wayland backend")
            root.hyprlandUnavailable = true
        }
    }
    property var settings: ({ dock: { position: "bottom", pinned: [], autohide: false } })
    property var palette: ({ base: "#eff1f5", surface: "#dce0e8", text: "#4c4f69", blue: "#1e66f5", muted: "#8c8fa1" })
    readonly property string edge: DockModel.normalizePosition(settings.dock.position)
    readonly property bool vertical: DockModel.isVertical(edge)
    property bool appsOpen: false
    property bool dockSettingsOpen: false
    property var appearancePreview: null
    property var stylePreview: null
    readonly property var dockStyle: Object.assign(DockModel.stylePreset("desktop"), settings.dock.style || {}, stylePreview || {})
    readonly property color dockBackgroundColor: dockStyle.backgroundColor || palette.surface
    function previewStyle(changes) { stylePreview = Object.assign({}, dockStyle, {theme: "custom"}, changes) }
    function selectDockTheme(name) { stylePreview = DockModel.stylePreset(name) }
    property bool resizingDock: false
    readonly property int dockSize: Math.max(24, Math.min(72, Number(appearancePreview ? appearancePreview.size : settings.dock.size) || 40))
    readonly property int dockMagnification: Math.max(100, Math.min(200, Number(appearancePreview ? appearancePreview.magnification : settings.dock.magnification) || 132))
    property real visualDockSize: dockSize
    Behavior on visualDockSize { enabled: !root.resizingDock; SmoothedAnimation { velocity: 200; duration: 160 } }
    readonly property real dockUnit: visualDockSize / 40
    // Reserve the largest supported cross-axis size once. Resizing the Wayland
    // surface for every slider event causes compositor configure/animation jitter.
    readonly property real dockDepth: 232
    function previewAppearance(size, magnification) {
        appearancePreview = { size: size, magnification: magnification }
    }
    function saveAppearance() { action(["appearance", String(dockSize), String(dockMagnification), "--style", JSON.stringify(dockStyle)]) }
    property var menuItem: null
    readonly property var trash: trashService
    TrashService {
        id: trashService
        helper: Quickshell.env("DOCK_TRASH_HELPER") || root.helper.replace(/dockctl$/, "dock-trash")
        colors: root.palette
    }
    property var launches: ({})
    property var launcherEntries: ({})
    property bool badgeBridgeReady: false
    property bool ownsUnityName: false
    Process {
        id: badgeBridge
        command: [Quickshell.env("DOCK_DBUS_PYTHON") || "/usr/bin/python3",
            Quickshell.env("DOCK_BADGE_HELPER") || root.helper.replace(/dockctl$/, "dock-badges")]
        running: true
        stderr: SplitParser { onRead: function(line) { console.warn("Dock badges:", line) } }
        stdout: SplitParser {
            onRead: function(line) {
                try {
                    var state = JSON.parse(line)
                    root.launcherEntries = state.entries || {}
                    root.badgeBridgeReady = state.ready === true
                    root.ownsUnityName = state.ownsUnityName === true
                } catch (error) { console.warn("Dock badges:", error) }
            }
        }
        onExited: {
            root.launcherEntries = {}
            root.badgeBridgeReady = false
            root.ownsUnityName = false
            badgeRetry.restart()
        }
    }
    Timer { id: badgeRetry; interval: 10000; onTriggered: badgeBridge.running = true }
    signal previewRequested(string key)
    function alpha(color, opacity) { var c = Qt.color(color); return Qt.rgba(c.r, c.g, c.b, opacity) }

    function action(args) { Quickshell.execDetached(["python3", helper].concat(args)) }
    function entry(key) { return DesktopEntries.byId(key) || DesktopEntries.heuristicLookup(key) }
    function icon(key) {
        if (key === "org.gnome.Nautilus") return Quickshell.iconPath("folder", true) || Qt.resolvedUrl("icons/folder.svg")
        var app = entry(key)
        return Quickshell.iconPath(app && app.icon ? app.icon : "application-x-executable", true) || Qt.resolvedUrl("icons/application.svg")
    }
    function name(key) { var app = entry(key); return app ? app.name : key }
    function focusWindow(window) { if (backend) backend.activate(window) }
    function closeWindow(window) { if (backend) backend.close(window) }
    function hideApp(item) { if (backend && item) item.windows.forEach(function(window) { backend.minimize(window) }) }
    function quitApp(item) { if (item) item.windows.slice().forEach(function(window) { root.closeWindow(window) }) }
    function launch(key) {
        var app = entry(key)
        if (app) {
            var pending = Object.assign({}, launches)
            var item = items.find(function(i) { return i.key === key })
            pending[key] = { count: item ? item.windows.length : 0, expires: Date.now() + 5000 }
            launches = pending
            app.execute()
        }
        root.appsOpen = false
    }
    Timer {
        interval: 150; running: Object.keys(root.launches).length > 0; repeat: true
        onTriggered: {
            var pending = Object.assign({}, root.launches)
            for (var key in pending) {
                var item = root.items.find(function(i) { return i.key === key })
                if (Date.now() >= pending[key].expires || (item && item.windows.length > pending[key].count)) delete pending[key]
            }
            if (JSON.stringify(pending) !== JSON.stringify(root.launches)) root.launches = pending
        }
    }
    function activate(item) {
        if (!item.windows.length) { launch(item.key); return }
        var ws = backend ? backend.activeWorkspace : -1
        var index = DockModel.pickWindow(item.windows, ws)
        focusWindow(item.windows[index])
    }

    FileView {
        path: root.configDir + "/settings.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.settings = JSON.parse(text())
                if (root.stylePreview && Object.keys(root.stylePreview).every(function(key) {
                    return root.settings.dock.style && root.settings.dock.style[key] === root.stylePreview[key]
                })) root.stylePreview = null
                // Acknowledge only the latest preview. An older asynchronous
                // save must not pull the slider's live size backwards.
                if (root.appearancePreview && root.settings.dock.size === root.appearancePreview.size
                    && root.settings.dock.magnification === root.appearancePreview.magnification) root.appearancePreview = null
            }
            catch (error) { console.warn("Dock settings:", error) }
        }
    }
    FileView {
        path: root.configDir + "/theme.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.palette = Object.assign({}, root.palette, JSON.parse(text())) }
            catch (error) { console.warn("Dock theme:", error) }
        }
    }

    readonly property var items: {
        var pins = DockModel.pinnedIds(settings.dock, {}).filter(function(key) { return !!root.entry(key) })
        var windows = []
        var all = backend ? backend.windows : []
        for (var i = 0; i < all.length; i++) {
            var window = all[i]
            var app = DesktopEntries.heuristicLookup(window.appId)
            windows.push(Object.assign({}, window, { key: app ? app.id : window.appId, hasEntry: true }))
        }
        var entries = {}
        for (var key in root.launcherEntries) {
            var launcher = root.entry(key)
            entries[DockModel.normalizeId(launcher ? launcher.id : key)] = root.launcherEntries[key]
        }
        return DockModel.withLauncherEntries(DockModel.buildItems(pins, windows), entries)
    }

    IpcHandler {
        target: "dock"
        function apps(): void { root.appsOpen = !root.appsOpen }
        function settings(): void { root.dockSettingsOpen = true }
        function status(): string {
            return JSON.stringify({ compositor: root.backend ? root.backend.name : "loading", capabilities: root.backend ? root.backend.capabilities : {},
                trash: { available: root.trash.available, count: root.trash.count, confirming: root.trash.confirming, busy: root.trash.busy, error: root.trash.error },
                edge: root.edge, size: root.dockSize, magnification: root.dockMagnification, settingsOpen: root.dockSettingsOpen,
                badges: { ready: root.badgeBridgeReady, ownsUnityName: root.ownsUnityName }, panels: Array.from(dockVariants.instances).map(function(panel) {
                return { screen: panel.screen.name, expanded: panel.expanded, overlapping: panel.overlapping, reveal: panel.reveal, preview: panel.previewKey,
                    resizing: panel.shelfItem.resizing, resizeHandle: panel.shelfItem.resizeHandleGeometry(), trashHandle: panel.shelfItem.trashHandleGeometry(), iconCache: panel.shelfItem.iconCache.summary }
            }), apps: root.items.map(function(item) {
                return { key: item.key, windows: item.windows.length, minimized: item.windows.filter(function(w) { return w.minimized }).length,
                    activity: item.activity, urgent: item.urgent }
            }) })
        }
        function activate(key: string): void {
            var item = root.items.find(function(i) { return i.key === key })
            if (item) root.activate(item)
        }
        function preview(key: string): void { root.previewRequested(key) }
        function minimize(): void { if (root.backend) root.backend.minimizeActive() }
        function restore(): void { if (root.backend) root.backend.restore() }
        function closeWindow(key: string): void {
            var item = root.items.find(function(i) { return i.key === key })
            if (item && item.windows.length) root.closeWindow(item.windows[DockModel.pickWindow(item.windows, root.backend.activeWorkspace)])
        }
    }

    Variants {
        id: dockVariants
        model: Quickshell.screens
        delegate: PanelWindow {
            id: dock
            required property var modelData
            screen: modelData
            readonly property var monitor: root.backend ? root.backend.monitorFor(screen) : null
            readonly property int workspace: root.backend ? root.backend.workspaceFor(monitor) : -1
            readonly property bool enabledHere: workspace >= 1
            property bool hovered: false
            property string previewKey: ""
            property var previewAnchor: null
            property bool dragging: false
            readonly property bool contextMenuOpen: dockMenu.visible || appMenu.visible || trashMenu.visible
            readonly property var shelfItem: shelf
            property real reveal: expanded ? 1 : 0
            Behavior on reveal { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            function keepPreview() { previewClose.stop() }
            function dismissPreview() { previewClose.restart() }
            readonly property var previewItem: root.items.find(function(i) { return i.key === dock.previewKey })
            readonly property bool overlapping: {
                if (!monitor || !root.backend || !root.backend.capabilities.overlap) return false
                var w = root.vertical ? 84 * root.dockUnit : shelf.visibleLength
                var h = root.vertical ? shelf.visibleLength : 84 * root.dockUnit
                var x = monitor.x + (root.edge === "left" ? 0 : root.edge === "right" ? screen.width - w : (screen.width - w) / 2 + shelf.axisOffset)
                var y = monitor.y + (root.edge === "top" ? dock.margins.top : root.edge === "bottom" ? screen.height - h : (screen.height - h) / 2 + shelf.axisOffset)
                return root.backend.overlaps(dock.workspace, Qt.rect(x, y, w, h))
            }
            readonly property bool expanded: hovered || dragging || root.dockSettingsOpen || root.trash.confirming || previews.visible || contextMenuOpen || (!root.settings.dock.autohide && !(root.settings.dock.intellihide !== false && overlapping))
            readonly property real length: root.vertical ? screen.height - 120 : screen.width - 80
            visible: enabledHere
            color: "transparent"
            implicitWidth: root.vertical ? root.dockDepth : length
            implicitHeight: root.vertical ? length : root.dockDepth
            // The surface stays fixed; only the shelf slides. Hidden pixels do
            // not intercept clicks, except for the three-pixel edge hotspot.
            mask: Region {
                x: root.vertical ? (root.edge === "right" ? dock.width - width : 0) : shelf.x
                y: root.vertical ? shelf.y : (root.edge === "bottom" ? dock.height - height : 0)
                width: root.vertical ? (dock.expanded ? (dock.hovered || dock.dragging ? shelf.depth : 86 * root.dockUnit) : 3) : shelf.width
                height: root.vertical ? shelf.height : (dock.expanded ? (dock.hovered || dock.dragging ? shelf.depth : 86 * root.dockUnit) : 3)
            }
            exclusiveZone: 0
            WlrLayershell.namespace: "dock"
            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            anchors {
                top: root.edge === "top"
                bottom: root.edge === "bottom"
                left: root.edge === "left"
                right: root.edge === "right"
            }
            margins {
                top: root.edge === "top" && root.backend ? root.backend.topMargin(monitor) : 0
                bottom: 0
                left: 0
                right: 0
            }
            Timer { id: hideDelay; interval: 650; onTriggered: dock.hovered = false }
            Timer { id: revealDelay; interval: 130; onTriggered: if (dockHover.hovered) dock.hovered = true }
            HoverHandler {
                id: dockHover
                onHoveredChanged: {
                    if (hovered) { hideDelay.stop(); if (dock.expanded) dock.hovered = true; else revealDelay.restart() }
                    else { revealDelay.stop(); hideDelay.restart() }
                }
            }
            Connections {
                target: root
                function onPreviewRequested(key) { dock.previewAnchor = shelf; dock.previewKey = key }
            }
            DockShelf {
                id: shelf
                iconCache: dockIconCache
                controller: root; host: dock
                iconSize: root.visualDockSize
                maximumMagnification: root.dockMagnification / 100
                x: root.vertical ? (root.edge === "right" ? dock.width - width : 0) : (dock.width - width) / 2 + axisOffset
                y: root.vertical ? (dock.height - height) / 2 + axisOffset : (root.edge === "bottom" ? dock.height - height : 0)
                enabled: dock.expanded
                transform: Translate {
                    x: root.vertical ? (1 - dock.reveal) * (root.edge === "right" ? root.dockDepth : -root.dockDepth) : 0
                    y: root.vertical ? 0 : (1 - dock.reveal) * (root.edge === "bottom" ? root.dockDepth : -root.dockDepth)
                }
                onLauncherMenu: function(anchor) { dockMenu.popupFor(anchor, root.edge, dock.contentItem) }
                onAppMenu: function(item, anchor) { root.menuItem = item; appMenu.popupFor(anchor, root.edge, dock.contentItem) }
                onTrashMenu: function(anchor) { trashMenu.popupFor(anchor, root.edge, dock.contentItem) }
            }
            Timer { id: previewClose; interval: 350; onTriggered: if (!previewHover.hovered) dock.previewKey = "" }
            IconCache {
                id: dockIconCache
                controller: root
                helper: Quickshell.env("DOCK_ICON_HELPER") || root.helper.replace(/dockctl$/, "dock-icons")
            }
            PopupWindow {
                id: previews
                visible: dock.enabledHere && !!dock.previewItem && dock.previewItem.windows.length > 0 && !dock.dragging
                color: "transparent"
                implicitWidth: Math.min(dock.previewItem ? dock.previewItem.windows.length * 246 + 22 : 268, 760, dock.screen.width - 32)
                implicitHeight: 250
                Behavior on implicitWidth { NumberAnimation { duration: 170; easing.type: Easing.OutCubic } }
                property real axis: {
                    if (!dock.previewAnchor || !dock.previewAnchor.parent) return root.vertical ? dock.height / 2 : dock.width / 2
                    if (dock.previewAnchor === shelf) return root.vertical ? shelf.y + shelf.height / 2 : shelf.x + shelf.width / 2
                    var point = dock.previewAnchor.parent.mapToItem(shelf,
                        dock.previewAnchor.x + dock.previewAnchor.width / 2,
                        dock.previewAnchor.y + dock.previewAnchor.height / 2)
                    return root.vertical ? point.y + shelf.y : point.x + shelf.x
                }
                Behavior on axis { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                anchor.window: dock
                anchor.rect.x: root.vertical ? shelf.x + (root.edge === "left" ? 108 : 20) * root.dockUnit : axis
                anchor.rect.y: root.vertical ? axis : shelf.y + (root.edge === "top" ? 108 : 20) * root.dockUnit
                anchor.edges: root.edge === "bottom" ? Edges.Top : root.edge === "top" ? Edges.Bottom : root.edge === "left" ? Edges.Right : Edges.Left
                anchor.gravity: anchor.edges
                Rectangle {
                    id: previewBody
                    anchors.fill: parent; anchors.margins: 4; radius: 18
                    color: root.alpha(root.palette.base, 0.88)
                    border.color: root.alpha(root.palette.text, 0.2)
                    NumberAnimation { id: previewFade; target: previewBody; property: "opacity"; from: 0.6; to: 1; duration: 160 }
                    Connections { target: dock; function onPreviewKeyChanged() { previewFade.restart() } }
                    HoverHandler { id: previewHover; onHoveredChanged: { if (hovered) previewClose.stop(); else previewClose.restart() } }
                    Text {
                        x: 16; y: 10; width: parent.width - 32; height: 24
                        readonly property int count: dock.previewItem ? dock.previewItem.windows.length : 0
                        text: root.name(dock.previewKey) + "  ·  " + count + (count === 1 ? " window" : " windows")
                        font.pixelSize: 12; font.weight: Font.DemiBold; color: root.palette.muted; elide: Text.ElideRight
                    }
                    ListView {
                        anchors.fill: parent; anchors.margins: 12; anchors.topMargin: 38
                        orientation: ListView.Horizontal; spacing: 10; clip: true
                        model: previews.visible ? dock.previewItem.windows : []
                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            width: 236; height: 188; radius: 13
                            color: cardMouse.containsMouse ? root.palette.surface : root.alpha(root.palette.surface, 0.45)
                            border.width: 1
                            border.color: card.modelData.activated ? root.alpha(root.palette.blue, 0.85) : root.alpha(root.palette.text, 0.08)
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Rectangle {
                                id: thumbnailMask; width: 220; height: 136; radius: 9
                                visible: false; layer.enabled: true; color: "white"
                            }
                            Item {
                                x: 8; y: 8; width: 220; height: 136
                                layer.enabled: true
                                layer.effect: MultiEffect { maskEnabled: true; maskSource: thumbnailMask }
                                Rectangle { anchors.fill: parent; color: root.alpha(root.palette.base, 0.65) }
                                ScreencopyView {
                                    id: capture; anchors.centerIn: parent
                                    width: implicitWidth; height: implicitHeight
                                    constraintSize: Qt.size(220, 136)
                                    captureSource: previews.visible ? card.modelData.wayland : null
                                    live: previews.visible && !card.modelData.minimized
                                }
                                Image { anchors.centerIn: parent; width: 48; height: 48; source: root.icon(dock.previewKey); visible: !capture.hasContent }
                            }
                            Text {
                                x: 10; y: 151; width: parent.width - 20; height: 32
                                text: (card.modelData.minimized ? "Restore · " : "") + card.modelData.title
                                color: root.palette.text; font.pixelSize: 12; elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap
                            }
                            MouseArea { id: cardMouse; anchors.fill: parent; hoverEnabled: true; onClicked: { root.focusWindow(card.modelData); dock.previewKey = "" } }
                            Rectangle {
                                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 13
                                width: 24; height: 24; radius: 12
                                color: closeMouse.containsMouse ? "#e06c75" : "#cc20222c"
                                Text { anchors.centerIn: parent; text: "×"; font.pixelSize: 18; color: "white" }
                                ToolTip.visible: closeMouse.containsMouse; ToolTip.text: "Close window"
                                MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; onClicked: root.closeWindow(card.modelData) }
                            }
                        }
                        ScrollBar.horizontal: ScrollBar {}
                    }
                }
            }
            DockMenu {
                id: dockMenu
                preferredWidth: 236
                colors: root.palette
                DockMenuItem { text: "Dock Settings…"; glyph: "⚙"; onTriggered: root.dockSettingsOpen = true }
                DockMenuItem { text: "Applications"; glyph: "⠿"; onTriggered: root.appsOpen = true }
                DockMenuSeparator {}
                DockMenu {
                    colors: root.palette
                    title: "Dock position"
                    DockMenuItem { text: "Bottom"; checkable: true; checked: root.edge === "bottom"; onTriggered: root.action(["position", "bottom"]) }
                    DockMenuItem { text: "Left"; checkable: true; checked: root.edge === "left"; onTriggered: root.action(["position", "left"]) }
                    DockMenuItem { text: "Right"; checkable: true; checked: root.edge === "right"; onTriggered: root.action(["position", "right"]) }
                    DockMenuItem { text: "Top"; checkable: true; checked: root.edge === "top"; onTriggered: root.action(["position", "top"]) }
                }
                DockMenuSeparator {}
                DockMenuItem { text: "Auto-hide"; checkable: true; checked: root.settings.dock.autohide; onTriggered: root.action(["autohide", "toggle"]) }
                DockMenuItem { text: "Hide when overlapped"; enabled: !!root.backend && root.backend.capabilities.overlap; checkable: true; checked: root.settings.dock.intellihide !== false; onTriggered: root.action(["intellihide", "toggle"]) }
                DockMenuSeparator {}
                DockMenuItem { text: "Restore minimized window"; glyph: "↥"; enabled: root.items.some(function(i) { return i.windows.some(function(w) { return w.minimized }) }); onTriggered: if (root.backend) root.backend.restore() }
            }
            DockMenu {
                id: appMenu
                colors: root.palette
                DockMenu {
                    title: "Options"
                    colors: root.palette
                    DockMenuItem {
                        text: "Keep in Dock"
                        checkable: true
                        checked: !!root.menuItem && root.menuItem.pinned
                        onTriggered: if (root.menuItem) root.action([root.menuItem.pinned ? "unpin" : "pin", root.menuItem.key])
                    }
                    DockMenuSeparator {}
                    DockMenuItem { text: "Dock Settings…"; onTriggered: root.dockSettingsOpen = true }
                }
                DockMenuSeparator {}
                Instantiator {
                    model: root.menuItem && root.menuItem.windows.length ? ["Show All Windows", "Hide", "Quit"] : ["Open"]
                    delegate: DockMenuItem {
                        required property string modelData
                        text: modelData
                        onTriggered: {
                            if (!root.menuItem) return
                            if (modelData === "Open") root.launch(root.menuItem.key)
                            else if (modelData === "Hide") root.hideApp(root.menuItem)
                            else if (modelData === "Quit") root.quitApp(root.menuItem)
                            else {
                                dock.previewAnchor = appMenu.anchorItem
                                dock.previewKey = root.menuItem.key
                                dock.keepPreview()
                            }
                        }
                    }
                    onObjectAdded: function(index, object) { appMenu.insertItem(index + 2, object) }
                    onObjectRemoved: function(index, object) { appMenu.removeItem(object) }
                }
            }
            DockMenu {
                id: trashMenu
                preferredWidth: 170
                colors: root.palette
                DockMenuItem { text: "Open Trash"; onTriggered: root.trash.open() }
                DockMenuItem {
                    text: "Empty Trash…"
                    enabled: root.trash.available && root.trash.count > 0 && !root.trash.busy
                    onTriggered: root.trash.requestEmpty()
                }
            }
        }
    }

    DockSettings { controller: root }

    PanelWindow {
        id: appGrid
        visible: root.appsOpen
        screen: root.backend && root.backend.focusedScreen ? root.backend.focusedScreen : Quickshell.screens[0]
        color: "transparent"
        implicitWidth: Math.min(820, screen ? screen.width - 80 : 820)
        implicitHeight: Math.min(620, screen ? screen.height - 120 : 620)
        exclusiveZone: 0
        WlrLayershell.namespace: "dock-app-grid"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.appsOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        onVisibleChanged: if (visible) { search.text = ""; search.forceActiveFocus() }
        readonly property color secondaryText: root.alpha(root.palette.text, 0.68)
        function launchSelection() {
            if (grid.currentIndex >= 0 && grid.currentIndex < grid.count) root.launch(grid.model[grid.currentIndex].id)
        }
        component LauncherButton: ToolButton {
            implicitWidth: 34; implicitHeight: 34
            contentItem: Text {
                text: parent.text; color: root.palette.text; font.pixelSize: 19
                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                radius: 9; color: parent.hovered ? root.palette.surface : "transparent"
                border.width: parent.activeFocus ? 1 : 0; border.color: root.palette.blue
            }
        }
        Rectangle {
            anchors.fill: parent
            radius: 24; color: root.palette.base
            border.color: root.alpha(root.palette.text, 0.16); border.width: 1
            Keys.onEscapePressed: root.appsOpen = false
            ColumnLayout {
                anchors.fill: parent; anchors.margins: 24; spacing: 16
                RowLayout {
                    Layout.fillWidth: true
                    Text { text: "Applications"; color: root.palette.text; font.pixelSize: 23; font.weight: Font.DemiBold; Layout.fillWidth: true }
                    Text { text: grid.count + (grid.count === 1 ? " app" : " apps"); color: appGrid.secondaryText; font.pixelSize: 12 }
                    LauncherButton { text: "×"; Accessible.name: "Close applications"; onClicked: root.appsOpen = false }
                }
                TextField {
                    id: search
                    Layout.fillWidth: true; Layout.preferredHeight: 48
                    leftPadding: 42; rightPadding: 44
                    placeholderText: "Search applications…"
                    placeholderTextColor: appGrid.secondaryText
                    color: root.palette.text
                    selectionColor: root.palette.blue
                    selectedTextColor: root.palette.base
                    font.pixelSize: 16
                    Accessible.name: "Search applications"
                    background: Rectangle {
                        color: root.alpha(root.palette.surface, 0.72); radius: 12
                        border.width: 1
                        border.color: search.activeFocus ? root.alpha(root.palette.blue, 0.8) : root.alpha(root.palette.text, 0.1)
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                    }
                    cursorDelegate: Rectangle {
                        width: 2; height: search.font.pixelSize + 4; color: root.palette.blue
                        visible: search.activeFocus && search.cursorVisible
                    }
                    Text { x: 15; anchors.verticalCenter: parent.verticalCenter; text: "⌕"; color: appGrid.secondaryText; font.pixelSize: 25 }
                    LauncherButton {
                        anchors.right: parent.right; anchors.rightMargin: 7; anchors.verticalCenter: parent.verticalCenter
                        visible: search.text.length > 0; text: "×"; Accessible.name: "Clear search"
                        onClicked: { search.clear(); search.forceActiveFocus() }
                    }
                    Keys.onEscapePressed: root.appsOpen = false
                    Keys.onDownPressed: { if (grid.count) { grid.currentIndex = 0; grid.forceActiveFocus() } }
                    onTextChanged: { grid.currentIndex = grid.count ? 0 : -1; grid.positionViewAtBeginning() }
                    onAccepted: appGrid.launchSelection()
                }
                GridView {
                    id: grid
                    Layout.fillWidth: true; Layout.fillHeight: true
                    clip: true
                    cellWidth: width / Math.max(1, Math.floor(width / 120)); cellHeight: 120
                    keyNavigationEnabled: true
                    keyNavigationWraps: true
                    highlightMoveDuration: 120
                    onCountChanged: currentIndex = count ? 0 : -1
                    model: DesktopEntries.applications.values.filter(function(app) {
                        var words = search.text.trim().toLowerCase().split(/\s+/)
                        var description = (app.name + " " + app.genericName + " " + app.comment + " " + app.id + " " + app.keywords.join(" ")).toLowerCase()
                        return !app.noDisplay && words.every(function(word) { return description.indexOf(word) >= 0 })
                    }).sort(function(a, b) { return a.name.localeCompare(b.name) })
                    Keys.onReturnPressed: appGrid.launchSelection()
                    Keys.onEnterPressed: appGrid.launchSelection()
                    Keys.onEscapePressed: root.appsOpen = false
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Backspace) {
                            search.forceActiveFocus(); search.text = search.text.slice(0, -1); event.accepted = true
                        } else if (event.text.length && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) && event.text.charCodeAt(0) >= 32) {
                            search.forceActiveFocus(); search.text += event.text; event.accepted = true
                        }
                    }
                    delegate: Rectangle {
                        id: appTile
                        required property var modelData
                        required property int index
                        readonly property bool selected: GridView.isCurrentItem
                        width: grid.cellWidth - 10; height: 110; radius: 14
                        color: selected ? root.alpha(root.palette.blue, 0.13) : gridMouse.containsMouse ? root.alpha(root.palette.surface, 0.75) : "transparent"
                        border.width: 1
                        border.color: selected ? root.alpha(root.palette.blue, grid.activeFocus ? 0.85 : 0.4) : "transparent"
                        Behavior on color { ColorAnimation { duration: 110 } }
                        AppTile { anchors.horizontalCenter: parent.horizontalCenter; y: 10; width: 54; height: 54; source: root.icon(appTile.modelData.id); tileColor: root.palette.surface }
                        Text {
                            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 7; rightMargin: 7; topMargin: 73 }
                            text: appTile.modelData.name; color: root.palette.text
                            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight; font.pixelSize: 12
                        }
                        ToolTip {
                            id: appTooltip
                            visible: gridMouse.containsMouse; delay: 700
                            text: appTile.modelData.name
                            padding: 9
                            contentItem: Text { text: appTooltip.text; color: root.palette.text; font.pixelSize: 12 }
                            background: Rectangle { radius: 8; color: root.palette.surface; border.width: 1; border.color: root.alpha(root.palette.text, 0.15) }
                        }
                        MouseArea {
                            id: gridMouse; anchors.fill: parent; hoverEnabled: true
                            onEntered: grid.currentIndex = appTile.index
                            onClicked: root.launch(appTile.modelData.id)
                        }
                    }
                    Column {
                        anchors.centerIn: parent; spacing: 10; visible: grid.count === 0
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "No matching applications"; color: root.palette.text; font.pixelSize: 18 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Try another name or clear your search."; color: appGrid.secondaryText; font.pixelSize: 13 }
                    }
                    ScrollBar.vertical: ScrollBar {
                        contentItem: Rectangle { implicitWidth: 4; implicitHeight: 30; radius: 2; color: root.alpha(root.palette.text, 0.4) }
                        background: Item {}
                    }
                }
                Text { text: "Type to search   ·   ↓ / arrows to select   ·   Enter to open   ·   Esc to close"; color: appGrid.secondaryText; font.pixelSize: 12 }
            }
        }
    }
}
