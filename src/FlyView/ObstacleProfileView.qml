import QtQuick

import QGroundControl
import QGroundControl.Controls

// Reusable obstacle visualization. Renders drone + radar cone + up to
// numTargets closest obstacles on a 2D plane. Used both as the inline
// mini view in FlyView and as the body of ObstacleProfilePopup.
Item {
    id: root

    property var vehicle: null
    property real maxRangeM: 60.0
    property int  viewMode: 0          // 0 = SIDE (elevation), 1 = TOP (azimuth)
    property int  numTargets: 8        // O_C1..O_CN (M/A/E)
    property bool showRangeLabels: true
    property bool showObstacleLabels: true
    property bool showAngleAxis: true
    property bool showForwardArrow: true
    property bool showModeLabel: true
    property real labelFontPointSize: ScreenTools.defaultFontPointSize

    readonly property var _named: (vehicle && vehicle.namedValueFloats) ? vehicle.namedValueFloats.values : ({})

    // Bumped on every namedValueFloats valuesChanged so the canvas repaints.
    property int _repaintTick: 0

    function _nf(key) {
        var v = _named && _named[key]
        if (!v) return null
        if (typeof v === "object" && v.value !== undefined) return v.value
        return null
    }

    function _obstacle(idx) {
        // Used at paint time; _repaintTick is referenced so callers' bindings
        // know to re-read when new values arrive.
        var t = _repaintTick
        var k = "O_C" + idx
        var d = _nf(k + "M")
        var a = _nf(k + "A")
        var e = _nf(k + "E")
        return {
            idx: idx,
            d: d !== null ? d : 0,
            a: a !== null ? a : 0,
            e: e !== null ? e : 0,
        }
    }

    onMaxRangeMChanged: profileCanvas.requestPaint()
    onViewModeChanged: profileCanvas.requestPaint()
    onWidthChanged: profileCanvas.requestPaint()
    onHeightChanged: profileCanvas.requestPaint()
    onNumTargetsChanged: profileCanvas.requestPaint()
    on_RepaintTickChanged: profileCanvas.requestPaint()

    Connections {
        target: (root.vehicle && root.vehicle.namedValueFloats) ? root.vehicle.namedValueFloats : null
        ignoreUnknownSignals: true
        function onValuesChanged() {
            root._repaintTick = (root._repaintTick + 1) & 0xffff
        }
    }

    QGCPalette { id: qgcPal }

    Canvas {
        id: profileCanvas
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var W = width
            var H = height
            if (W <= 0 || H <= 0) return

            var droneColor   = qgcPal.text
            var coneColor    = qgcPal.colorRed
            var gridColor    = qgcPal.windowShade
            var axisColor    = qgcPal.windowTransparentText
            var labelColor   = qgcPal.text
            var obsColor     = qgcPal.colorOrange
            var fwdColor     = qgcPal.colorGreen
            var sideMode     = (root.viewMode === 0)

            var marginPx = root.labelFontPointSize * 1.3
            var dx, dy, pxPerMeter

            if (sideMode) {
                // SIDE: cone is asymmetric — 30° up, 60° down. Position the drone
                // so the upper edge just clears the top margin; the larger downward
                // extent gets all the remaining height.
                //   needed_above = sin(30°) * coneR = 0.5  * coneR
                //   needed_below = sin(60°) * coneR = 0.866 * coneR
                //   coneR_max    = (H - 2*marginPx) / (0.5 + 0.866)
                dx = marginPx + root.labelFontPointSize * 0.5
                var horizSpace = W - dx - marginPx * 4   // outer ring labels need room
                var coneRVert  = (H - 2 * marginPx) / (0.5 + 0.866)
                var coneRHoriz = horizSpace
                var coneR_ = Math.min(coneRVert, coneRHoriz)
                pxPerMeter = coneR_ / root.maxRangeM
                dy = marginPx + 0.5 * coneR_              // upper edge at marginPx
            } else {
                dx = W / 2
                dy = H - marginPx
                var fwdSpace  = H - marginPx * 2
                var sideSpace = (W / 2 - marginPx) / 0.707
                pxPerMeter = Math.min(fwdSpace / root.maxRangeM,
                                      sideSpace / root.maxRangeM)
            }
            if (pxPerMeter <= 0) return

            var coneR = root.maxRangeM * pxPerMeter

            // ───── Outer range ring + label only ──────────────────────────
            ctx.strokeStyle = gridColor
            ctx.lineWidth   = 1
            ctx.font        = root.labelFontPointSize + "pt sans-serif"
            ctx.setLineDash([4, 4])
            ctx.beginPath()
            if (sideMode) {
                ctx.moveTo(dx + coneR, marginPx)
                ctx.lineTo(dx + coneR, H - marginPx)
            } else {
                ctx.arc(dx, dy, coneR, Math.PI, 2 * Math.PI)
            }
            ctx.stroke()
            ctx.setLineDash([])
            // Outer-range label removed: the popup title row already shows the
            // configured max range, and each obstacle carries its own distance.

            // ───── Angle axis (Y in SIDE, radial in TOP) ──────────────────
            if (root.showAngleAxis) {
                ctx.strokeStyle = axisColor
                ctx.fillStyle   = axisColor
                ctx.lineWidth   = 1

                if (sideMode) {
                    // SIDE: dashed rays from drone out to the outer ring at each
                    // tick angle; labels sit just past the outer ring so they spread
                    // around the arc and never overlap.
                    var sideTicks = [-60, -45, -30, -15, 0, 15, 30]
                    for (var st = 0; st < sideTicks.length; st++) {
                        var degVal = sideTicks[st]
                        var rad = degVal * Math.PI / 180
                        var endX = dx + coneR * Math.cos(rad)
                        var endY = dy - coneR * Math.sin(rad)
                        ctx.setLineDash(degVal === 0 ? [] : [2, 5])
                        ctx.beginPath()
                        ctx.moveTo(dx, dy)
                        ctx.lineTo(endX, endY)
                        ctx.stroke()
                        // Label just past the outer ring along the same ray
                        var labelGap = root.labelFontPointSize * 0.6
                        var lx = endX + labelGap * Math.cos(rad)
                        var ly = endY - labelGap * Math.sin(rad) + root.labelFontPointSize * 0.35
                        ctx.fillStyle = axisColor
                        ctx.fillText(degVal + "°", lx, ly)
                    }
                    ctx.setLineDash([])
                } else {
                    // TOP view: radial angle lines from drone
                    var topTicks = [-45, -30, -15, 0, 15, 30, 45]
                    for (var tt = 0; tt < topTicks.length; tt++) {
                        var d = topTicks[tt]
                        var rTop = d * Math.PI / 180
                        ctx.setLineDash(d === 0 ? [] : [2, 5])
                        ctx.beginPath()
                        ctx.moveTo(dx, dy)
                        ctx.lineTo(dx + coneR * Math.sin(rTop), dy - coneR * Math.cos(rTop))
                        ctx.stroke()
                        // Label at outer end
                        var lblX = dx + (coneR + root.labelFontPointSize * 0.6) * Math.sin(rTop)
                        var lblY = dy - (coneR + root.labelFontPointSize * 0.6) * Math.cos(rTop)
                        ctx.fillStyle = axisColor
                        ctx.fillText(d + "°", lblX - root.labelFontPointSize * 0.6, lblY)
                    }
                    ctx.setLineDash([])
                }
            }

            // ───── Radar coverage cone outline (FIXED winding) ───────────
            ctx.strokeStyle = coneColor
            ctx.lineWidth   = 2
            ctx.beginPath()

            if (sideMode) {
                // SIDE: tilted-down cone, from upper edge (-highRad) down to lower edge (+lowRad).
                var coneLow  = +60
                var coneHigh = +30
                var lowRad  = coneLow  * Math.PI / 180
                var highRad = coneHigh * Math.PI / 180
                ctx.moveTo(dx, dy)
                // Upper edge first
                ctx.lineTo(dx + coneR * Math.cos(-highRad), dy + coneR * Math.sin(-highRad))
                // Arc smoothly down to lower edge
                var steps = 24
                for (var k = 1; k <= steps; k++) {
                    var t = -highRad + (lowRad + highRad) * (k / steps)
                    ctx.lineTo(dx + coneR * Math.cos(t), dy + coneR * Math.sin(t))
                }
                ctx.lineTo(dx, dy)
            } else {
                // TOP: fan forward; go from drone → LEFT edge → arc to RIGHT edge → drone.
                // Original code went drone → right → left (crossed back over itself).
                var fovRad = 45 * Math.PI / 180
                ctx.moveTo(dx, dy)
                // Left edge first
                ctx.lineTo(dx + coneR * Math.sin(-fovRad), dy - coneR * Math.cos(-fovRad))
                // Arc smoothly from left to right
                var stepsT = 24
                for (var m = 1; m <= stepsT; m++) {
                    var u = -fovRad + 2 * fovRad * (m / stepsT)
                    ctx.lineTo(dx + coneR * Math.sin(u), dy - coneR * Math.cos(u))
                }
                ctx.lineTo(dx, dy)
            }
            ctx.stroke()

            // ───── Obstacle markers (up to numTargets) ────────────────────
            for (var n = 1; n <= root.numTargets; n++) {
                var o = root._obstacle(n)
                if (!o.d || o.d <= 0.01) continue   // skip zero/unset
                var ang = sideMode ? o.e : o.a
                var rad2 = ang * Math.PI / 180
                var ox, oy
                if (sideMode) {
                    ox = dx + o.d * Math.cos(rad2) * pxPerMeter
                    oy = dy - o.d * Math.sin(rad2) * pxPerMeter
                } else {
                    ox = dx + o.d * Math.sin(rad2) * pxPerMeter
                    oy = dy - o.d * Math.cos(rad2) * pxPerMeter
                }
                ctx.strokeStyle = obsColor
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.moveTo(dx, dy)
                ctx.lineTo(ox, oy)
                ctx.stroke()
                ctx.fillStyle = obsColor
                ctx.beginPath()
                ctx.arc(ox, oy, root.labelFontPointSize * 0.45, 0, 2 * Math.PI)
                ctx.fill()
                if (root.showObstacleLabels) {
                    ctx.fillStyle = labelColor
                    ctx.fillText("#" + o.idx + "  " + o.d.toFixed(1) + "m  " + ang.toFixed(0) + "°",
                                 ox + 8, oy - 4)
                }
            }

            // ───── Forward arrow (SIDE only) ──────────────────────────────
            if (sideMode && root.showForwardArrow) {
                var arrowLen = root.labelFontPointSize * 2.5
                ctx.strokeStyle = fwdColor
                ctx.fillStyle   = fwdColor
                ctx.lineWidth   = 2
                ctx.beginPath()
                ctx.moveTo(dx, dy)
                ctx.lineTo(dx + arrowLen, dy)
                ctx.stroke()
                // arrowhead
                var head = root.labelFontPointSize * 0.5
                ctx.beginPath()
                ctx.moveTo(dx + arrowLen, dy)
                ctx.lineTo(dx + arrowLen - head, dy - head * 0.6)
                ctx.lineTo(dx + arrowLen - head, dy + head * 0.6)
                ctx.closePath()
                ctx.fill()
                ctx.fillText("Fwd", dx + arrowLen + 2, dy - 4)
            }

            // ───── Drone / origin marker ─────────────────────────────────
            // Crosshair + filled dot.
            ctx.strokeStyle = droneColor
            ctx.lineWidth = 1
            var cross = root.labelFontPointSize * 1.0
            ctx.beginPath()
            ctx.moveTo(dx - cross, dy)
            ctx.lineTo(dx + cross, dy)
            ctx.moveTo(dx, dy - cross)
            ctx.lineTo(dx, dy + cross)
            ctx.stroke()
            ctx.fillStyle = droneColor
            ctx.beginPath()
            ctx.arc(dx, dy, root.labelFontPointSize * 0.55, 0, 2 * Math.PI)
            ctx.fill()
            ctx.fillStyle = qgcPal.window
            ctx.beginPath()
            ctx.arc(dx, dy, root.labelFontPointSize * 0.22, 0, 2 * Math.PI)
            ctx.fill()

            // ───── Mode label ────────────────────────────────────────────
            if (root.showModeLabel) {
                ctx.fillStyle = labelColor
                ctx.font = (root.labelFontPointSize + 1) + "pt sans-serif"
                ctx.fillText(sideMode ? qsTr("SIDE — elevation (deg)") : qsTr("TOP — azimuth (deg)"),
                             marginPx * 0.5, marginPx * 0.9)
            }
        }
    }
}
