import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

/// v3's navigation display: bottom-left of the viewport, where DJI Pilot 2
/// and Auterion both put the aircraft-centred view. Heading-up: the aircraft
/// always points to the top of the ring and the compass turns around it, so
/// "ahead" is always up and the forward radar's sector is always drawn there.
///
/// What DJI draws here, drawn here: a heading ring with the cardinals, the
/// aircraft centred, its speed vector, the home point as an H on the rim at
/// its relative bearing, and colour-coded obstacle sensing -- a forward
/// sector for the horizontal radar and a vertical bar with the return marked
/// on it, green / amber / red for clear / inside the release margin / inside
/// the stop trigger. What is Rosor's own: the closest distance as the largest
/// number on the card, the CLEAR / INSIDE TRIGGER state as a word, and the
/// along-track profile one tap away.
///
/// The logic moved verbatim from the obstacle band: the O_C1M / U3M / O_HZ
/// named floats, the RADAR_FWD_M trigger and its hysteresis. The band carried
/// the same numbers as a full-width strip; the card carries them in a
/// reserved slot the map's own controls are inset away from.
Rectangle {
    id: root

    property var vehicle: null

    /// Emitted when the pilot asks for the full along-track profile.
    signal profileRequested()

    /// Fixed footprint so the inset the map is given never moves.
    width:  ScreenTools.defaultFontPixelWidth * 16.7
    height: ScreenTools.defaultFontPixelHeight * 6.0
    radius: ScreenTools.defaultFontPixelHeight * 0.19
    // #20242a at 0.90: the viewport chrome tone, fixed rather than themed
    // because it sits over imagery in either theme.
    color:  Qt.rgba(0.125, 0.141, 0.165, 0.90)

    // Semantic accents are fixed -- they mean danger / good / alert / action
    // wherever they appear.
    readonly property color _danger:  "#b52b2b"
    readonly property color _good:    "#008f2d"
    readonly property color _alert:   "#eecc44"
    readonly property color _accent:  "#3A9BDC"
    readonly property color _fg:      "#ffffff"
    readonly property color _fgDim:   "#c9ccce"
    readonly property color _label:   "#8d959d"

    readonly property bool _vehicleAvailable: vehicle !== null && vehicle !== undefined

    // --------------------------------------------------------------- radar

    readonly property var _named: (_vehicleAvailable && vehicle.namedValueFloats)
                                    ? vehicle.namedValueFloats.values
                                    : ({})

    function _namedValue(key, minValue) {
        var e = root._named && root._named[key]
        if (e && typeof e === "object" && e.value !== undefined && e.value > minValue) {
            return e.value
        }
        return NaN
    }

    readonly property real _closest:    _namedValue("O_C1M", 0.01)
    readonly property real _radarAlt:   _namedValue("U3M", 0.2)
    readonly property real _obstacleHz: _namedValue("O_HZ", -1)
    readonly property bool _closestKnown: !isNaN(_closest)

    // The stop distance comes off the aircraft, never from a local guess.
    RadarAvoidParams {
        id:      radarParams
        vehicle: root.vehicle
    }

    /// Inside the trigger only when the trigger is actually known AND the
    /// script is enabled. Unknown stays neutral rather than alarming.
    ///
    /// Latched with the script's own hysteresis: it arms at RADAR_FWD_M and
    /// releases only past RADAR_FWD_M + AVOID_CLEAR_MARGIN_M -- the same two
    /// distances u300-avoid.lua uses, so the card and the aircraft agree. A
    /// bare "closest <= trigger" test chatters while a return sits on the
    /// threshold, which on a stop indicator reads as the aircraft changing
    /// its mind.
    property bool insideTrigger: false

    function _updateInsideTrigger() {
        if (!radarParams.haveTrigger || radarParams.avoidEnabled === false || !root._closestKnown) {
            root.insideTrigger = false
        } else if (root.insideTrigger) {
            if (root._closest > radarParams.clearM) {
                root.insideTrigger = false
            }
        } else if (root._closest <= radarParams.fwdTrigM) {
            root.insideTrigger = true
        }
    }

    on_ClosestChanged: { root._updateInsideTrigger(); ring.requestPaint() }
    onInsideTriggerChanged: ring.requestPaint()

    Connections {
        target: radarParams
        ignoreUnknownSignals: true
        function onFwdTrigMChanged()     { root._updateInsideTrigger(); ring.requestPaint() }
        function onClearMChanged()       { ring.requestPaint() }
        function onHaveTriggerChanged()  { root._updateInsideTrigger(); ring.requestPaint() }
        function onAvoidEnabledChanged() { root._updateInsideTrigger(); ring.requestPaint() }
    }

    /// The three bands the sensing is drawn in: 0 clear, 1 near (inside the
    /// release margin but not, or no longer, stopping), 2 the latched stop
    /// state. Same distances as the script, so the bands mean what the
    /// aircraft will do. An int, not a colour, so every consumer compares a
    /// number -- colour equality in QML JS is not something to build on.
    readonly property int _sensingState: root.insideTrigger ? 2
                                          : (root._closestKnown && radarParams.haveTrigger
                                             && root._closest <= radarParams.clearM) ? 1
                                          : 0
    readonly property color _sensingColor: _sensingState === 2 ? root._danger
                                            : _sensingState === 1 ? root._alert
                                            : root._good

    readonly property string _rdrText: isNaN(root._radarAlt)
                                        ? qsTr("RDR —")
                                        : qsTr("RDR %1 m").arg(root._radarAlt.toFixed(1))

    readonly property string _hzText: isNaN(root._obstacleHz)
                                        ? qsTr("— Hz")
                                        : qsTr("%1 Hz").arg(root._obstacleHz.toFixed(0))

    readonly property string _triggerText: {
        if (radarParams.avoidEnabled === false) {
            return qsTr("avoid off")
        }
        if (!radarParams.haveTrigger) {
            return ""
        }
        return qsTr("trigger %1 m").arg(radarParams.fwdTrigM.toFixed(0))
    }

    // ---------------------------------------------------------- navigation

    readonly property real _heading:      _vehicleAvailable ? vehicle.heading.rawValue       : NaN
    readonly property real _homeBearing:  _vehicleAvailable ? vehicle.headingToHome.rawValue : NaN
    readonly property real _homeDistance: _vehicleAvailable ? vehicle.distanceToHome.rawValue : NaN
    readonly property real _speed:        (_vehicleAvailable && vehicle.groundSpeed) ? vehicle.groundSpeed.rawValue : NaN

    readonly property bool _headingKnown: !isNaN(_heading)
    readonly property bool _homeKnown:    _headingKnown && !isNaN(_homeBearing) && !isNaN(_homeDistance)

    on_HeadingChanged:      ring.requestPaint()
    on_HomeBearingChanged:  ring.requestPaint()
    on_HomeDistanceChanged: ring.requestPaint()
    on_SpeedChanged:        ring.requestPaint()
    on_VehicleAvailableChanged: ring.requestPaint()

    // Tap anywhere on the card for the full profile with its zoom controls --
    // the same gesture the band had, on the slot that replaced it.
    MouseArea {
        id:             cardMouse
        anchors.fill:   parent
        onClicked:      root.profileRequested()
    }

    QGCLabel {
        id:                 header
        anchors.left:       parent.left
        anchors.top:        parent.top
        anchors.margins:    ScreenTools.defaultFontPixelWidth * 0.8
        text:               qsTr("NAV · OBSTACLE")
        font.pointSize:     ScreenTools.smallFontPointSize
        color:              root._label
    }

    // The trigger distance, against the reading it limits. Blank when the
    // vehicle has not told us one.
    QGCLabel {
        anchors.right:      parent.right
        anchors.top:        parent.top
        anchors.margins:    ScreenTools.defaultFontPixelWidth * 0.8
        text:               root._triggerText
        visible:            text !== ""
        font.pointSize:     ScreenTools.smallFontPointSize
        color:              root.insideTrigger ? root._danger : root._label
    }

    // ------------------------------------------------------------- the ring
    //
    // Drawn, not laid out: everything here rotates or scales with live values,
    // and one Canvas is cheaper on the handheld than a dozen rotating Items.
    Canvas {
        id:             ring
        anchors.top:    header.bottom
        anchors.bottom: readouts.top
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.topMargin:    ScreenTools.defaultFontPixelHeight * 0.1
        anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.1

        // The vertical obstacle bar's column, on the right, kept clear of the ring.
        readonly property real barWidth:  ScreenTools.defaultFontPixelWidth * 0.9
        readonly property real barMargin: ScreenTools.defaultFontPixelWidth * 0.8

        onWidthChanged:  requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()

        function _rgba(c, a) {
            return Qt.rgba(c.r, c.g, c.b, a)
        }

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()

            var ringRight = width - barWidth - barMargin * 2
            var cx = ringRight * 0.5
            var cy = height * 0.5
            var R  = Math.max(8, Math.min(height * 0.5 - 4, ringRight * 0.42))
            var deg = Math.PI / 180
            var heading = root._headingKnown ? root._heading : 0

            // Ring. Faint when there is nothing to orient.
            ctx.lineWidth = 1.5
            ctx.strokeStyle = root._vehicleAvailable ? "rgba(255,255,255,0.35)" : "rgba(255,255,255,0.18)"
            ctx.beginPath()
            ctx.arc(cx, cy, R, 0, 2 * Math.PI)
            ctx.stroke()

            if (!root._vehicleAvailable) {
                return
            }

            // Cardinals, heading-up: north sits at minus the heading.
            ctx.strokeStyle = "rgba(255,255,255,0.9)"
            ctx.fillStyle   = "rgba(255,255,255,0.9)"
            ctx.font = "bold " + Math.round(ScreenTools.smallFontPointSize * 1.3) + "px sans-serif"
            ctx.textAlign = "center"
            ctx.textBaseline = "middle"
            for (var k = 0; k < 4; k++) {
                var a = (k * 90 - heading) * deg
                var sx = Math.sin(a), cyv = -Math.cos(a)
                ctx.beginPath()
                ctx.moveTo(cx + sx * R, cy + cyv * R)
                ctx.lineTo(cx + sx * (R + 5), cy + cyv * (R + 5))
                ctx.stroke()
                if (k === 0) {
                    ctx.fillText(qsTr("N"), cx + sx * (R + 13), cy + cyv * (R + 13))
                }
            }

            // Forward sensing sector: the U300 looks ahead, so the sector is
            // always up. Coloured by what the aircraft will do about it.
            if (root._closestKnown) {
                var sc = root._sensingColor
                ctx.fillStyle = _rgba(sc, 0.5)
                ctx.beginPath()
                ctx.moveTo(cx, cy)
                ctx.arc(cx, cy, R, -120 * deg, -60 * deg)
                ctx.closePath()
                ctx.fill()

                // The return itself, on the forward axis, at a scale where the
                // stop trigger lands a little past half way out.
                var scale = radarParams.haveTrigger && radarParams.fwdTrigM > 0
                            ? (R * 0.55) / radarParams.fwdTrigM
                            : R / 60
                var rr = Math.min(R * 0.95, root._closest * scale)
                ctx.fillStyle = _rgba(sc, 1.0)
                ctx.strokeStyle = "rgba(255,255,255,0.9)"
                ctx.lineWidth = 1
                ctx.beginPath()
                ctx.arc(cx, cy - rr, 4.5, 0, 2 * Math.PI)
                ctx.fill()
                ctx.stroke()
            }

            // Speed vector: straight up, ten metres a second fills the ring.
            if (!isNaN(root._speed) && root._speed > 0.05) {
                var vl = Math.min(R * 0.95, (root._speed / 10) * R)
                ctx.strokeStyle = "rgba(255,255,255,0.9)"
                ctx.lineWidth = 2
                ctx.beginPath()
                ctx.moveTo(cx, cy)
                ctx.lineTo(cx, cy - vl)
                ctx.stroke()
            }

            // Home, on the rim at its bearing relative to the nose.
            if (root._homeKnown) {
                var rel = (root._homeBearing - heading) * deg
                var hx = cx + Math.sin(rel) * R * 0.85
                var hy = cy - Math.cos(rel) * R * 0.85
                ctx.fillStyle = root._alert
                ctx.beginPath()
                ctx.arc(hx, hy, 7, 0, 2 * Math.PI)
                ctx.fill()
                ctx.fillStyle = "#000000"
                ctx.font = "bold " + Math.round(ScreenTools.smallFontPointSize * 1.1) + "px sans-serif"
                ctx.fillText(qsTr("H"), hx, hy + 0.5)
            }

            // The aircraft, always up.
            ctx.fillStyle = root._accent
            ctx.strokeStyle = "rgba(255,255,255,0.9)"
            ctx.lineWidth = 1.2
            ctx.beginPath()
            ctx.moveTo(cx, cy - 15)
            ctx.lineTo(cx + 9, cy + 7)
            ctx.lineTo(cx, cy + 2)
            ctx.lineTo(cx - 9, cy + 7)
            ctx.closePath()
            ctx.fill()
            ctx.stroke()

            // Vertical obstacle bar: far at the top, the stop distance at the
            // bottom, the current return marked. Bands dim except the live one.
            var bx = width - barMargin - barWidth
            var by0 = 4, by1 = height - 4
            var bh = (by1 - by0) / 3
            var live = root._closestKnown ? root._sensingState : -1
            var bands = [root._good, root._alert, root._danger]
            for (var b = 0; b < 3; b++) {
                ctx.fillStyle = _rgba(bands[b], b === live ? 1.0 : 0.30)
                ctx.fillRect(bx, by0 + b * bh, barWidth, bh - 1)
            }
            if (root._closestKnown) {
                // Position: the trigger is the bottom of the middle band, the
                // release margin its top; beyond that the far band, linearly.
                var trig = radarParams.haveTrigger ? radarParams.fwdTrigM : 25
                var clr  = radarParams.haveTrigger ? Math.max(radarParams.clearM, trig + 0.1) : trig * 1.5
                var far  = clr * 1.6
                var d = root._closest
                var frac
                if (d <= trig) {
                    frac = 1.0 - (d / trig) * (1 / 3)
                } else if (d <= clr) {
                    frac = (2 / 3) - ((d - trig) / (clr - trig)) * (1 / 3)
                } else {
                    frac = Math.max(0, (1 / 3) - ((d - clr) / (far - clr)) * (1 / 3))
                }
                var my = by0 + frac * (by1 - by0)
                ctx.strokeStyle = "#ffffff"
                ctx.lineWidth = 2
                ctx.beginPath()
                ctx.moveTo(bx - 3, my)
                ctx.lineTo(bx + barWidth + 3, my)
                ctx.stroke()
            }
        }
    }

    // With nothing connected the ring says so, once, instead of a dash.
    QGCLabel {
        anchors.centerIn:   ring
        text:               qsTr("No aircraft")
        font.pointSize:     ScreenTools.smallFontPointSize
        color:              root._label
        visible:            !root._vehicleAvailable
    }

    // ------------------------------------------------------------ readouts
    ColumnLayout {
        id:                     readouts
        anchors.left:           parent.left
        anchors.right:          parent.right
        anchors.bottom:         parent.bottom
        anchors.leftMargin:     ScreenTools.defaultFontPixelWidth * 0.8
        anchors.rightMargin:    ScreenTools.defaultFontPixelWidth * 0.8
        anchors.bottomMargin:   ScreenTools.defaultFontPixelHeight * 0.25
        spacing:                ScreenTools.defaultFontPixelHeight * 0.1
        visible:                root._vehicleAvailable

        RowLayout {
            Layout.fillWidth:   true
            spacing:            ScreenTools.defaultFontPixelWidth * 0.4

            QGCLabel {
                Layout.alignment:   Qt.AlignBaseline
                text:               root._closestKnown ? root._closest.toFixed(1) : "—"
                font.pointSize:     ScreenTools.largeFontPointSize * 1.4
                font.bold:          true
                color:              root.insideTrigger ? root._danger : root._fg
            }

            QGCLabel {
                Layout.alignment:   Qt.AlignBaseline
                text:               qsTr("m")
                font.pointSize:     ScreenTools.defaultFontPointSize
                color:              root._fgDim
                visible:            root._closestKnown
            }

            Item { Layout.fillWidth: true }

            // Sized to its text but coloured as a state, in the sensing bands.
            Rectangle {
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.85
                Layout.preferredWidth:  stateLabel.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.4
                Layout.alignment:       Qt.AlignVCenter
                radius:                 ScreenTools.defaultFontPixelHeight * 0.12
                color:                  root._sensingColor
                visible:                root._closestKnown && radarParams.haveTrigger

                QGCLabel {
                    id:                 stateLabel
                    anchors.centerIn:   parent
                    text:               root._sensingState === 2 ? qsTr("INSIDE TRIGGER")
                                        : root._sensingState === 1 ? qsTr("NEAR") : qsTr("CLEAR")
                    font.pointSize:     ScreenTools.smallFontPointSize
                    font.bold:          true
                    // Dark text on amber, which is too light for white.
                    color:              root._sensingState === 1 ? "#000000" : "white"
                }
            }
        }

        RowLayout {
            Layout.fillWidth:   true
            spacing:            0

            QGCLabel {
                text:           root._rdrText
                font.pointSize: ScreenTools.smallFontPointSize
                color:          root._label
            }

            Item { Layout.fillWidth: true }

            QGCLabel {
                text:           root._hzText
                font.pointSize: ScreenTools.smallFontPointSize
                color:          root._label
            }

            Item { Layout.preferredWidth: ScreenTools.defaultFontPixelWidth }

            QGCLabel {
                text:           qsTr("profile")
                font.pointSize: ScreenTools.smallFontPointSize
                color:          root._accent
            }
        }
    }

    Rectangle {
        anchors.fill:   parent
        radius:         parent.radius
        color:          "transparent"
        border.color:   cardMouse.pressed ? Qt.rgba(1, 0.6, 0, 0.7) : Qt.rgba(1, 1, 1, 0.12)
        border.width:   cardMouse.pressed ? 2 : 1
    }
}
