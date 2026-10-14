import QtQuick
import QtQuick.Controls

ToolTip {
    id: label
    property string edge: "bottom"
    delay: 0
    timeout: -1
    padding: 7
    leftPadding: 12
    rightPadding: 12
    // Keep the text pill's size while letting the pointer extend toward its icon.
    topInset: edge === "top" ? -6 : 0
    bottomInset: edge === "bottom" ? -6 : 0
    leftInset: edge === "left" ? -6 : 0
    rightInset: edge === "right" ? -6 : 0
    x: edge === "left" ? parent.width + 10 : edge === "right" ? -width - 10 : (parent.width - width) / 2
    y: edge === "top" ? parent.height + 10 : edge === "bottom" ? -height - 10 : (parent.height - height) / 2
    contentItem: Text {
        text: label.text
        font.pixelSize: 12
        color: "#24252a"
    }
    background: Canvas {
        id: bubble
        antialiasing: true
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Connections { target: label; function onEdgeChanged() { bubble.requestPaint() } }
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            ctx.clearRect(0, 0, width, height)
            var vertical = label.edge === "left" || label.edge === "right"
            var w = vertical ? height : width
            var h = vertical ? width : height
            ctx.translate(width / 2, height / 2)
            ctx.rotate(label.edge === "top" ? Math.PI : label.edge === "left" ? Math.PI / 2 : label.edge === "right" ? -Math.PI / 2 : 0)
            ctx.translate(-w / 2, -h / 2)
            var l = 0.5, t = 0.5, r = w - 0.5, b = h - 6.5
            var radius = Math.min((r - l - 14) / 2, (b - t) / 2)
            var center = w / 2
            // One continuous silhouette avoids a seam where the tail meets the pill.
            ctx.beginPath()
            ctx.moveTo(l + radius, t)
            ctx.lineTo(r - radius, t)
            ctx.quadraticCurveTo(r, t, r, t + radius)
            ctx.lineTo(r, b - radius)
            ctx.quadraticCurveTo(r, b, r - radius, b)
            ctx.lineTo(center + 7, b)
            ctx.bezierCurveTo(center + 4, b, center + 3, b + 3.5, center + 1.3, b + 5)
            ctx.quadraticCurveTo(center, b + 6.5, center - 1.3, b + 5)
            ctx.bezierCurveTo(center - 3, b + 3.5, center - 4, b, center - 7, b)
            ctx.lineTo(l + radius, b)
            ctx.quadraticCurveTo(l, b, l, b - radius)
            ctx.lineTo(l, t + radius)
            ctx.quadraticCurveTo(l, t, l + radius, t)
            ctx.closePath()
            ctx.fillStyle = "#e6d7d7dc"
            ctx.fill()
            ctx.strokeStyle = "#70ffffff"
            ctx.lineWidth = 0.7
            ctx.stroke()
        }
    }
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 80 } }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 60 } }
}
