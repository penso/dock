import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: trash
    required property string helper
    required property var colors
    property bool available: false
    property int count: 0
    property string error: ""
    property bool confirming: false
    property bool busy: false
    property string emptyIcon: ""
    property string fullIcon: ""
    readonly property string icon: (available && count > 0 ? fullIcon : emptyIcon)
        || Qt.resolvedUrl(available && count > 0 ? "icons/trash-full.svg" : "icons/trash.svg")
    readonly property string label: !available ? "Trash" : count ? "Trash · " + count + (count === 1 ? " item" : " items") : "Trash is empty"
    function open() { Quickshell.execDetached(["gio", "open", "trash:///"]) }
    function requestEmpty() {
        if (!available || count === 0 || busy) return
        error = ""
        confirming = true
    }
    function confirmEmpty() {
        if (!confirming || !available || count === 0 || busy) return
        busy = true
        emptyProcess.running = true
    }
    Process {
        id: watcher
        command: [Quickshell.env("DOCK_DBUS_PYTHON") || "/usr/bin/python3", trash.helper]
        running: true
        stdout: SplitParser {
            onRead: function(line) {
                try {
                    var state = JSON.parse(line)
                    trash.available = state.available === true
                    trash.count = Number(state.count) || 0
                    trash.error = state.error || ""
                    trash.emptyIcon = state.emptyIcon || ""
                    trash.fullIcon = state.fullIcon || ""
                } catch (error) { console.warn("Dock Trash:", error) }
            }
        }
        stderr: SplitParser { onRead: function(line) { console.warn("Dock Trash:", line) } }
        onExited: { trash.available = false; retry.restart() }
    }
    Timer { id: retry; interval: 30000; onTriggered: watcher.running = true }
    Process {
        id: emptyProcess
        command: ["gio", "trash", "--empty"]
        stderr: StdioCollector { id: emptyError }
        onExited: function(code) {
            trash.busy = false
            if (code === 0) trash.confirming = false
            else trash.error = emptyError.text.trim() || "Trash could not be emptied."
        }
    }
    FloatingWindow {
        id: confirmation
        visible: trash.confirming
        title: "Empty Trash?"
        implicitWidth: 420
        implicitHeight: 240 + (trash.error ? 80 : 0)
        color: trash.colors.base
        onClosed: trash.confirming = false
        onVisibleChanged: if (visible) cancelButton.forceActiveFocus()
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16
            Keys.onEscapePressed: if (!trash.busy) trash.confirming = false
            Text { text: "Empty Trash?"; color: trash.colors.text; font.pixelSize: 22; font.weight: Font.DemiBold }
            Text {
                Layout.fillWidth: true
                text: "Permanently delete all items in Trash? This cannot be undone."
                wrapMode: Text.Wrap
                color: trash.colors.text
                font.pixelSize: 14
            }
            Text { Layout.fillWidth: true; visible: !!trash.error; text: trash.error; color: "#e5484d"; wrapMode: Text.Wrap }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.alignment: Qt.AlignRight
                Button { id: cancelButton; text: "Cancel"; enabled: !trash.busy; onClicked: trash.confirming = false }
                Button { text: trash.busy ? "Emptying…" : "Empty Trash"; enabled: !trash.busy && trash.count > 0; onClicked: trash.confirmEmpty() }
            }
        }
    }
}
