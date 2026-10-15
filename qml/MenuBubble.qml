import QtQuick
import QtQuick.Effects

Canvas {
    id: bubble
    property bool pointed: false
    property string edge: "bottom"
    property real tailPosition: 28
    antialiasing: true
    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: "#55000000"
        shadowBlur: 0.45
        shadowVerticalOffset: 3
        autoPaddingEnabled: false
    }
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPointedChanged: requestPaint()
    onEdgeChanged: requestPaint()
    onTailPositionChanged: requestPaint()
    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.clearRect(0, 0, width, height)
        var vertical = edge === "left" || edge === "right"
        var w = vertical ? height : width
        var h = vertical ? width : height
        ctx.translate(width / 2, height / 2)
        ctx.rotate(edge === "top" ? Math.PI : edge === "left" ? Math.PI / 2 : edge === "right" ? -Math.PI / 2 : 0)
        ctx.translate(-w / 2, -h / 2)
        var depth = pointed ? 8 : 0
        var l = 12.5, t = 12.5, r = w - 12.5, b = h - 12.5 - depth
        var radius = 10
        var center = 12 + ((edge === "top" || edge === "right") ? w - 24 - tailPosition : tailPosition)
        center = Math.max(l + radius + 10, Math.min(r - radius - 10, center))
        ctx.beginPath()
        ctx.moveTo(l + radius, t)
        ctx.lineTo(r - radius, t)
        ctx.quadraticCurveTo(r, t, r, t + radius)
        ctx.lineTo(r, b - radius)
        ctx.quadraticCurveTo(r, b, r - radius, b)
        if (pointed) {
            ctx.lineTo(center + 10, b)
            ctx.bezierCurveTo(center + 5, b, center + 3, b + 5, center + 1.3, b + 6.7)
            ctx.quadraticCurveTo(center, b + 8.2, center - 1.3, b + 6.7)
            ctx.bezierCurveTo(center - 3, b + 5, center - 5, b, center - 10, b)
        }
        ctx.lineTo(l + radius, b)
        ctx.quadraticCurveTo(l, b, l, b - radius)
        ctx.lineTo(l, t + radius)
        ctx.quadraticCurveTo(l, t, l + radius, t)
        ctx.closePath()
        ctx.fillStyle = "#f2c5c5ca"
        ctx.fill()
        ctx.strokeStyle = "#99ffffff"
        ctx.lineWidth = 0.7
        ctx.stroke()
    }
}
