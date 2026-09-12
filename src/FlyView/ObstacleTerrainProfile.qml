import QtQuick

import QGroundControl
import QGroundControl.Controls

// Side profile in the style of the ObstacleHUD v1.9 terrain view: the aircraft
// sits at the centre of a fixed along-track window with the terrain built up
// behind it from the downward radar, and forward returns chained ahead.
//
// Unlike the polar ObstacleProfileView this is a Cartesian along-track/height
// projection, so it needs history: ground points are recorded in absolute AMSL
// against the distance travelled, then drawn relative to the aircraft's current
// position. Constants mirror obstacle_hud.py / ObstacleHudTerrain.cs -- keep the
// three in lockstep.
Item {
    id: root

    property var  vehicle:      null

    // Fixed view window, aircraft centred.
    property real viewUpM:      5.0     ///< height window above the aircraft
    property real viewDownM:    40.0    ///< ...and below it
    property real halfWidthM:   30.0    ///< along-track span either side
    property int  numObstacles: 6
    property real u3mMinValidM: 0.2     ///< under this is "no reading", not ground at 0
    property real elevHighBiasM: 6.0    ///< Beeton reports up to this high...
    property real elevLowBiasM:  1.0    ///< ...and about this low
    /// Forward trigger distance, live from the vehicle's RADAR_FWD_M. NaN until
    /// it is actually known -- a guessed threshold on a stop-distance readout
    /// would disagree with what the aircraft will really do.
    property real triggerM:     NaN
    /// Downward radar floor (RADAR_DWN_M), as a height above the ground. NaN
    /// when unknown.
    property real downFloorM:   NaN
    /// LOITER / BRAKE / AUTO-OFS, from RADAR_STOP_MD -- what the vehicle does
    /// when the forward trigger is crossed.
    property string stopModeLabel: ""
    /// Slung-payload ignore band, live from RADAR_IGN_M / RADAR_IGN_W. The
    /// tether keeps the load at a constant RANGE whatever angle it swings to,
    /// so range alone identifies it. NaN or <= 0 means no band is configured.
    property real ignoreRangeM:     NaN
    property real ignoreHalfWidthM: 0

    /// U3M is published tilt-corrected, but the ignore band is defined on SLANT
    /// range, so a reading has to be converted back before it can be tested:
    /// slant = U3M / factor. cos(0) * cos(20), mirroring u300-avoid.lua --
    /// revisit if the downward radar is ever remounted.
    readonly property real _u3mTiltFactor: Math.cos(0) * Math.cos(20 * Math.PI / 180)
    property int  maxHistory:   400

    property bool showGrid:     true
    property bool showLabels:   true
    property real labelFontPointSize: ScreenTools.smallFontPointSize

    readonly property var _named: (vehicle && vehicle.namedValueFloats) ? vehicle.namedValueFloats.values : null

    property real _amsl:    vehicle ? vehicle.altitudeAMSL.rawValue : 0
    property int  _tick:    0

    /// True when the downward radar has locked onto the slung load instead of
    /// the ground: U3M flattens at about the tether length and is NOT ground
    /// range, so it must not be recorded as terrain or read as AGL.
    readonly property bool _birdLocked: {
        _tick
        var u3 = _nf("U3M")
        return _valid(u3) && u3 >= root.u3mMinValidM &&
               _inIgnoreBand(u3 / root._u3mTiltFactor)
    }

    // Accumulated along-track distance and the absolute-AMSL trails hung off it.
    property real _sNow:        0
    property var  _lastCoord:   null
    property var  _ground:      []   ///< [{ s, amsl }] terrain from the down radar
    property var  _echoes:      []   ///< [{ s, amsl }] forward returns once passed

    function _nf(key) {
        if (!_named) return NaN
        var v = _named[key]
        if (!v) return NaN
        if (typeof v === "object" && v.value !== undefined) return v.value
        return NaN
    }

    function _valid(v) { return !isNaN(v) && isFinite(v) }

    /// Mirror of u300-avoid.lua's payload_ignored(): a straight-line SLANT
    /// range within RADAR_IGN_W of RADAR_IGN_M is the slung load, not terrain
    /// and not an obstacle.
    function _inIgnoreBand(slantM) {
        if (!_valid(root.ignoreRangeM) || root.ignoreRangeM <= 0) {
            return false
        }
        if (!_valid(slantM)) {
            return false
        }
        return Math.abs(slantM - root.ignoreRangeM) <= Math.max(0, root.ignoreHalfWidthM)
    }

    function _obstacle(idx) {
        var d = _nf("O_C" + idx + "M")
        var a = _nf("O_C" + idx + "A")
        var e = _nf("O_C" + idx + "E")
        if (!_valid(d) || d <= 0.05) return null
        return {
            d: d,
            az: _valid(a) ? a : 0,
            el: _valid(e) ? e : 0,
            // O_C*M is the script's 3D straight-line range, which is exactly
            // what the band is defined on. v1.5 scripts drop banded returns
            // before publishing, so one arriving here means an older script or
            // params changed since: ghost it rather than colour it a threat,
            // which is what the avoidance logic would do with it.
            ignored: _inIgnoreBand(d)
        }
    }

    // Record a terrain sample under the aircraft and age the trails out of the
    // window behind us.
    function _record() {
        var u3 = _nf("U3M")
        if (_valid(u3) && u3 >= root.u3mMinValidM && root._amsl !== 0 && !root._birdLocked) {
            var g = root._ground.slice()
            g.push({ s: root._sNow, amsl: root._amsl - u3 })
            while (g.length > root.maxHistory) g.shift()
            root._ground = g
        }
        var cutoff = root._sNow - root.halfWidthM * 1.2
        if (root._ground.length && root._ground[0].s < cutoff) {
            var g2 = root._ground.filter(function (p) { return p.s >= cutoff })
            root._ground = g2
        }
        if (root._echoes.length && root._echoes[0].s < cutoff) {
            root._echoes = root._echoes.filter(function (p) { return p.s >= cutoff })
        }
    }

    onVehicleChanged: {
        _ground = []
        _echoes = []
        _sNow = 0
        _lastCoord = null
    }

    Connections {
        target: (root.vehicle && root.vehicle.namedValueFloats) ? root.vehicle.namedValueFloats : null
        ignoreUnknownSignals: true
        function onValuesChanged() {
            root._record()
            root._tick = (root._tick + 1) & 0xffff
        }
    }

    Connections {
        target: root.vehicle
        ignoreUnknownSignals: true
        function onCoordinateChanged() {
            var c = root.vehicle ? root.vehicle.coordinate : null
            if (!c || !c.isValid) return
            if (root._lastCoord && root._lastCoord.isValid) {
                var step = root._lastCoord.distanceTo(c)
                if (step > 0 && step < 200) root._sNow += step
            }
            root._lastCoord = c
        }
    }

    on_TickChanged:     profile.requestPaint()
    on_SNowChanged:     profile.requestPaint()
    onWidthChanged:     profile.requestPaint()
    onHeightChanged:    profile.requestPaint()

    QGCPalette { id: qgcPal }

    Canvas {
        id:           profile
        anchors.fill: parent
        antialiasing: true

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            var W = width, H = height
            if (W <= 0 || H <= 0) return

            var pad     = root.labelFontPointSize * 2.2
            var left    = pad
            var top     = root.labelFontPointSize * 0.8
            var right   = W - root.labelFontPointSize * 0.8
            var bottom  = H - root.labelFontPointSize * 1.4
            if (right <= left || bottom <= top) return

            var spanM   = root.viewUpM + root.viewDownM
            var sx      = (right - left) / (root.halfWidthM * 2)
            var sy      = (bottom - top) / spanM

            function X(dM) {
                var d = Math.min(Math.max(dM, -root.halfWidthM), root.halfWidthM)
                return left + (d + root.halfWidthM) * sx
            }
            function Y(hM) { return top + (root.viewUpM - hM) * sy }
            function YC(y) { return Math.min(Math.max(y, top + 3), bottom - 3) }

            // ── frame ────────────────────────────────────────────────────
            ctx.fillStyle = Qt.rgba(0, 0, 0, 0.35)
            ctx.fillRect(left, top, right - left, bottom - top)

            if (root.showGrid) {
                ctx.strokeStyle = qgcPal.windowShade
                ctx.lineWidth   = 1
                ctx.font        = root.labelFontPointSize + "pt sans-serif"
                ctx.setLineDash([3, 4])
                for (var h = 0; h >= -root.viewDownM; h -= 10) {
                    var gy = Y(h)
                    ctx.beginPath(); ctx.moveTo(left, gy); ctx.lineTo(right, gy); ctx.stroke()
                    if (root.showLabels) {
                        ctx.fillStyle = qgcPal.windowTransparentText
                        ctx.fillText(h + "m", 2, gy + root.labelFontPointSize * 0.4)
                    }
                }
                for (var d2 = -root.halfWidthM; d2 <= root.halfWidthM; d2 += 15) {
                    var gx = X(d2)
                    ctx.beginPath(); ctx.moveTo(gx, top); ctx.lineTo(gx, bottom); ctx.stroke()
                }
                ctx.setLineDash([])
            }

            // ── terrain from the downward radar ──────────────────────────
            var g = root._ground
            if (g.length > 1) {
                ctx.beginPath()
                var started = false
                for (var i = 0; i < g.length; i++) {
                    var gx2 = X(g[i].s - root._sNow)
                    var gy2 = YC(Y(g[i].amsl - root._amsl))
                    if (!started) { ctx.moveTo(gx2, gy2); started = true }
                    else          { ctx.lineTo(gx2, gy2) }
                }
                // close down to the bottom edge for the fill
                var lastX = X(g[g.length - 1].s - root._sNow)
                var firstX = X(g[0].s - root._sNow)
                ctx.lineTo(lastX, bottom)
                ctx.lineTo(firstX, bottom)
                ctx.closePath()
                ctx.fillStyle = Qt.rgba(0.45, 0.34, 0.20, 0.55)
                ctx.fill()

                // ridge line on top of the fill
                ctx.beginPath()
                for (var j = 0; j < g.length; j++) {
                    var rx = X(g[j].s - root._sNow)
                    var ry = YC(Y(g[j].amsl - root._amsl))
                    if (j === 0) ctx.moveTo(rx, ry); else ctx.lineTo(rx, ry)
                }
                ctx.strokeStyle = qgcPal.colorOrange
                ctx.lineWidth   = 2
                ctx.stroke()
            }

            // ── passed echoes ────────────────────────────────────────────
            ctx.fillStyle = qgcPal.windowTransparentText
            for (var e2 = 0; e2 < root._echoes.length; e2++) {
                var ex = X(root._echoes[e2].s - root._sNow)
                var ey = YC(Y(root._echoes[e2].amsl - root._amsl))
                ctx.beginPath(); ctx.arc(ex, ey, 1.5, 0, 2 * Math.PI); ctx.fill()
            }

            // ── forward returns: chain + whiskers ────────────────────────
            var chain  = []
            var ghosts = []
            for (var k = 1; k <= root.numObstacles; k++) {
                var o = root._obstacle(k)
                if (!o) continue
                var elRad = o.el * Math.PI / 180
                var along = o.d * Math.cos(elRad)
                var hgt   = o.d * Math.sin(elRad)
                if (o.ignored) {
                    ghosts.push({ x: along, y: hgt, d: o.d })
                } else {
                    chain.push({ x: along, y: hgt, d: o.d })
                }
            }
            chain.sort(function (a, b) { return a.x - b.x })

            // Returns inside the payload band draw as hollow ghosts: seen, but
            // known to be our own load, and never joined into the chain.
            for (var gi = 0; gi < ghosts.length; gi++) {
                ctx.strokeStyle = qgcPal.colorGrey
                ctx.lineWidth   = 1
                ctx.beginPath()
                ctx.arc(X(ghosts[gi].x), YC(Y(ghosts[gi].y)), 3, 0, 2 * Math.PI)
                ctx.stroke()
            }

            if (chain.length) {
                // whiskers: range is exact, height is coarse by design
                for (var w = 0; w < chain.length; w++) {
                    var wx  = X(chain[w].x)
                    var wyH = YC(Y(chain[w].y + root.elevHighBiasM))
                    var wyL = YC(Y(chain[w].y - root.elevLowBiasM))
                    ctx.strokeStyle = chain[w].d <= root.triggerM ? qgcPal.colorRed : qgcPal.colorYellow
                    ctx.lineWidth   = 2
                    ctx.beginPath(); ctx.moveTo(wx, wyH); ctx.lineTo(wx, wyL); ctx.stroke()
                }
                // chain joining the returns to each other only
                ctx.beginPath()
                for (var c = 0; c < chain.length; c++) {
                    var cx2 = X(chain[c].x)
                    var cy2 = YC(Y(chain[c].y))
                    if (c === 0) ctx.moveTo(cx2, cy2); else ctx.lineTo(cx2, cy2)
                }
                ctx.strokeStyle = qgcPal.colorRed
                ctx.lineWidth   = 1.5
                ctx.stroke()

                for (var m = 0; m < chain.length; m++) {
                    ctx.fillStyle = chain[m].d <= root.triggerM ? qgcPal.colorRed : qgcPal.colorYellow
                    ctx.beginPath()
                    ctx.arc(X(chain[m].x), YC(Y(chain[m].y)), 3, 0, 2 * Math.PI)
                    ctx.fill()
                }
            }

            // ── action line ahead, exactly at RADAR_FWD_M ────────────────
            // Correct as a vertical line because a return's X *is* its range.
            if (root._valid(root.triggerM) && root.triggerM > 0 && root.triggerM < root.halfWidthM) {
                var tx = X(root.triggerM)
                ctx.strokeStyle = qgcPal.colorRed
                ctx.lineWidth   = 1
                ctx.setLineDash([2, 4])
                ctx.beginPath(); ctx.moveTo(tx, top); ctx.lineTo(tx, bottom); ctx.stroke()
                ctx.setLineDash([])

                if (root.showLabels && root.stopModeLabel !== "") {
                    ctx.fillStyle = qgcPal.colorRed
                    ctx.fillText(root.stopModeLabel, tx + 3, top + root.labelFontPointSize * 1.6)
                }
            }

            // ── downward floor at RADAR_DWN_M above the ground ───────────
            var u3Floor = root._nf("U3M")
            if (root._valid(root.downFloorM) && root.downFloorM > 0 &&
                    root._valid(u3Floor) && u3Floor >= root.u3mMinValidM) {
                var fy = Y(root.downFloorM - u3Floor)
                if (fy >= top && fy <= bottom) {
                    ctx.strokeStyle = qgcPal.colorOrange
                    ctx.lineWidth   = 1
                    ctx.setLineDash([4, 4])
                    ctx.beginPath(); ctx.moveTo(left, fy); ctx.lineTo(right, fy); ctx.stroke()
                    ctx.setLineDash([])
                }
            }

            // ── aircraft at the centre ───────────────────────────────────
            var ax = X(0), ay = Y(0)
            ctx.strokeStyle = qgcPal.text
            ctx.lineWidth   = 2
            ctx.beginPath()
            ctx.moveTo(ax - 7, ay); ctx.lineTo(ax + 7, ay)
            ctx.moveTo(ax, ay - 4); ctx.lineTo(ax, ay + 4)
            ctx.stroke()

            // downward radar reading under the aircraft
            var u3 = root._nf("U3M")
            if (root._valid(u3) && u3 >= root.u3mMinValidM) {
                // Locked onto the slung load this is the tether, not the
                // ground -- say so rather than letting it read as AGL.
                var u3Colour = root._birdLocked ? qgcPal.colorOrange : qgcPal.colorGreen
                ctx.strokeStyle = u3Colour
                ctx.lineWidth   = 1
                ctx.setLineDash([1, 3])
                ctx.beginPath(); ctx.moveTo(ax, ay); ctx.lineTo(ax, YC(Y(-u3))); ctx.stroke()
                ctx.setLineDash([])
                if (root.showLabels) {
                    ctx.fillStyle = u3Colour
                    ctx.fillText(root._birdLocked ? qsTr("payload %1m").arg(u3.toFixed(1))
                                                  : (u3.toFixed(1) + "m"),
                                 ax + 4, YC(Y(-u3)) - 2)
                }
            }
        }
    }
}
