import QtQuick

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap

// Mission Planner style primary flight display: artificial horizon with a
// speed tape on the left and an altitude tape on the right, a heading strip
// across the top and the downward radar altitude boxed underneath.
//
// Selectable from Application Settings -> Fly View -> instrument panel, so it
// sits alongside the round compass/attitude instruments rather than replacing
// them.
Rectangle {
    id:     root
    // Sits in a RowLayout beside TelemetryValuesBar, so it has to leave room for
    // it rather than overrunning it.
    width:  ScreenTools.defaultFontPixelHeight * 17
    height: ScreenTools.defaultFontPixelHeight * 11
    color:  QGroundControl.globalPalette.window
    radius: ScreenTools.defaultFontPixelHeight / 4

    property real extraInset:       0
    property real extraValuesWidth: 0

    property var  _vehicle:     globals.activeVehicle
    property real _roll:        _vehicle ? _vehicle.roll.rawValue        : 0
    property real _pitch:       _vehicle ? _vehicle.pitch.rawValue       : 0
    property real _heading:     _vehicle ? _vehicle.heading.rawValue     : 0
    property real _groundSpeed: _vehicle ? _vehicle.groundSpeed.rawValue : 0
    property real _climbRate:   _vehicle ? _vehicle.climbRate.rawValue   : 0

    // AGL: terrain-referenced altitude, falling back to relative-to-home when
    // no terrain data is available for the current position.
    property real _aglRaw:      _vehicle ? _vehicle.altitudeAboveTerr.rawValue : NaN
    property real _relAlt:      _vehicle ? _vehicle.altitudeRelative.rawValue  : 0
    property bool _aglValid:    !isNaN(_aglRaw) && isFinite(_aglRaw)
    property real _agl:         _aglValid ? _aglRaw : _relAlt

    // Downward radar altitude, published by the U300 kit as NAMED_VALUE_FLOAT U3M.
    property var  _named:       (_vehicle && _vehicle.namedValueFloats) ? _vehicle.namedValueFloats.values : null
    property real _radarAlt: {
        if (!_named) return NaN
        var f = _named["U3M"]
        if (!f) return NaN
        if (typeof f === "object" && f.value !== undefined) return f.value
        return NaN
    }
    // The Lua treats anything under DIST_MIN_M as "no reading", never ground at 0 m.
    property bool _radarValid: !isNaN(_radarAlt) && isFinite(_radarAlt) && _radarAlt >= 0.2

    // Also used as a PipView thumbnail, where the pane is only ~144px tall. Fixed
    // strip heights ate the whole pane there and left nothing for the horizon, so
    // the chrome scales with the available height and the labels shrink with it.
    readonly property bool _compact:    height < ScreenTools.defaultFontPixelHeight * 9
    readonly property real _chromeFont: _compact ? ScreenTools.smallFontPointSize * 0.85
                                                 : ScreenTools.smallFontPointSize
    readonly property real _tapeWidth:  _compact ? ScreenTools.defaultFontPixelWidth * 4
                                                 : ScreenTools.defaultFontPixelWidth * 5
    readonly property real _headingH:   _compact ? 0 : ScreenTools.defaultFontPixelHeight * 1.6
    readonly property real _radarH:     _compact ? ScreenTools.defaultFontPixelHeight * 1.15
                                                 : ScreenTools.defaultFontPixelHeight * 1.6
    readonly property color _boxBg:     Qt.rgba(0, 0, 0, 0.75)
    readonly property color _tapeBg:    Qt.rgba(0, 0, 0, 0.45)
    readonly property color _lineColor: "#ffffff"
    readonly property color _radarColor: "#6fd3a6"

    // Prevent clicks falling through to the map underneath.
    DeadMouseArea { anchors.fill: parent }

    // ---------------------------------------------------------------- horizon
    Item {
        id: horizonArea
        anchors.top:    headingStrip.bottom
        anchors.bottom: radarStrip.top
        anchors.left:   parent.left
        anchors.right:  parent.right
        clip:           true

        MPArtificialHorizon {
            anchors.fill: parent
            rollAngle:    root._roll
            pitchAngle:   root._pitch
        }

        // Roll scale turns with the aircraft and the pointer stays put, which is
        // how MP draws it. Ticks only -- the angle is read from the numeral.
        Canvas {
            id:              rollScale
            anchors.fill:    parent
            rotation:        -root._roll
            transformOrigin: Item.Center
            visible:         !root._compact

            onWidthChanged:  requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()

                var cx = width / 2
                var cy = height / 2
                var r  = Math.min(width, height) * 0.40
                if (r <= 0) {
                    return
                }

                ctx.strokeStyle = "white"
                ctx.lineWidth   = 2

                ctx.beginPath()
                ctx.arc(cx, cy, r, -Math.PI / 2 - Math.PI / 3, -Math.PI / 2 + Math.PI / 3)
                ctx.stroke()

                var marks = [0, -10, 10, -20, 20, -30, 30, -45, 45, -60, 60]
                for (var i = 0; i < marks.length; i++) {
                    var a     = marks[i]
                    var theta = (-90 + a) * Math.PI / 180
                    var len   = (a === 0) ? 12 : ((Math.abs(a) >= 30) ? 10 : 6)

                    ctx.beginPath()
                    ctx.moveTo(cx + r * Math.cos(theta), cy + r * Math.sin(theta))
                    ctx.lineTo(cx + (r + len) * Math.cos(theta), cy + (r + len) * Math.sin(theta))
                    ctx.stroke()
                }
            }
        }

        // Fixed roll pointer at the apex of the scale.
        Canvas {
            id:              rollPointer
            anchors.fill:    parent
            visible:         !root._compact

            onWidthChanged:  requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()

                var cx = width / 2
                var cy = height / 2
                var r  = Math.min(width, height) * 0.40
                if (r <= 0) {
                    return
                }

                ctx.fillStyle = "#ff0000"
                ctx.beginPath()
                ctx.moveTo(cx, cy - r + 2)
                ctx.lineTo(cx - 7, cy - r - 11)
                ctx.lineTo(cx + 7, cy - r - 11)
                ctx.closePath()
                ctx.fill()
            }
        }

        // Fixed aircraft symbol: red chevron with the green wing bar and the red
        // side bars, as on MP's HUD.
        Canvas {
            id:              aircraftSymbol
            anchors.fill:    parent

            onWidthChanged:  requestPaint()
            onHeightChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.reset()

                var cx = width / 2
                var cy = height / 2

                ctx.lineCap = "round"

                ctx.strokeStyle = "#ff0000"
                ctx.lineWidth   = 4
                ctx.beginPath()
                ctx.moveTo(width * 0.05, cy)
                ctx.lineTo(width * 0.21, cy)
                ctx.moveTo(width * 0.79, cy)
                ctx.lineTo(width * 0.95, cy)
                ctx.stroke()

                ctx.strokeStyle = "#008000"
                ctx.lineWidth   = 3
                ctx.beginPath()
                ctx.moveTo(cx - width * 0.12, cy)
                ctx.lineTo(cx + width * 0.12, cy)
                ctx.stroke()

                ctx.strokeStyle = "#ff0000"
                ctx.lineWidth   = 5
                ctx.lineJoin    = "round"
                ctx.beginPath()
                ctx.moveTo(cx - width * 0.12, cy + height * 0.075)
                ctx.lineTo(cx, cy)
                ctx.lineTo(cx + width * 0.12, cy + height * 0.075)
                ctx.stroke()
            }
        }

        // Roll above the pointer, pitch below the chevron.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top:              parent.top
            anchors.topMargin:        2
            visible:                  !root._compact
            color:                    Qt.rgba(0, 0, 0, 0.62)
            width:                    rollValue.implicitWidth + ScreenTools.defaultFontPixelWidth
            height:                   rollValue.implicitHeight + 2

            QGCLabel {
                id:               rollValue
                anchors.centerIn: parent
                text:             Math.round(root._roll) + "°"
                color:            root._lineColor
                font.pointSize:   ScreenTools.smallFontPointSize
                font.family:      "Arial"
            }
        }

        Rectangle {
            anchors.horizontalCenter:     parent.horizontalCenter
            anchors.verticalCenter:       parent.verticalCenter
            anchors.verticalCenterOffset: parent.height * 0.14
            visible:                      !root._compact
            color:                        Qt.rgba(0, 0, 0, 0.62)
            width:                        pitchValue.implicitWidth + ScreenTools.defaultFontPixelWidth
            height:                       pitchValue.implicitHeight + 2

            QGCLabel {
                id:               pitchValue
                anchors.centerIn: parent
                text:             (root._pitch >= 0 ? "+" : "") + Math.round(root._pitch) + "°"
                color:            root._lineColor
                font.pointSize:   ScreenTools.smallFontPointSize
                font.family:      "Arial"
            }
        }
    }

    // ------------------------------------------------------------ speed tape
    VerticalTape {
        id:                 speedTape
        visible:            !root._compact
        anchors.top:        horizonArea.top
        anchors.bottom:     horizonArea.bottom
        anchors.left:       parent.left
        width:              root._tapeWidth
        value:              root._groundSpeed
        minValue:           0
        tickStep:           5
        pixelsPerUnit:      ScreenTools.defaultFontPixelHeight / 2.5
        boxOnRight:         true
        labelPointSize:     root._chromeFont
        valuePointSize:     root._compact ? root._chromeFont : ScreenTools.defaultFontPointSize
        tapeColor:          root._tapeBg
        boxColor:           root._boxBg
        textColor:          root._lineColor
        caption:            qsTr("GS m/s")
    }

    // --------------------------------------------------------- altitude tape
    VerticalTape {
        id:                 altTape
        visible:            !root._compact
        anchors.top:        horizonArea.top
        anchors.bottom:     horizonArea.bottom
        anchors.right:      parent.right
        width:              root._tapeWidth
        value:              root._agl
        tickStep:           5
        pixelsPerUnit:      ScreenTools.defaultFontPixelHeight / 2.5
        boxOnRight:         false
        labelPointSize:     root._chromeFont
        valuePointSize:     root._compact ? root._chromeFont : ScreenTools.defaultFontPointSize
        tapeColor:          root._tapeBg
        boxColor:           root._boxBg
        textColor:          root._lineColor
        caption:            root._aglValid ? qsTr("AGL m") : qsTr("REL m")
    }

    // Climb rate, small, beside the altitude tape
    QGCLabel {
        anchors.right:          altTape.left
        anchors.rightMargin:    2
        anchors.verticalCenter: horizonArea.verticalCenter
        anchors.verticalCenterOffset: ScreenTools.defaultFontPixelHeight * 1.6
        visible:                !root._compact
        text:                   (root._climbRate >= 0 ? "+" : "") + root._climbRate.toFixed(1)
        font.pointSize:         ScreenTools.smallFontPointSize
        color:                  root._lineColor
        style:                  Text.Outline
        styleColor:             "black"
    }

    // ------------------------------------------------------- heading strip
    Rectangle {
        id:             headingStrip
        anchors.top:    parent.top
        anchors.left:   parent.left
        anchors.right:  parent.right
        height:         root._headingH
        visible:        !root._compact
        color:          root._tapeBg

        Item {
            id:           headingTape
            anchors.fill: parent
            clip:         true

            property real pixelsPerDegree: root.width / 90

            Repeater {
                model: 25
                delegate: Item {
                    property int tickHeading: (Math.round(root._heading / 15) * 15) + ((index - 12) * 15)
                    property real delta: {
                        var d = tickHeading - root._heading
                        while (d > 180)  d -= 360
                        while (d < -180) d += 360
                        return d
                    }
                    x:      (headingStrip.width / 2) + (delta * headingTape.pixelsPerDegree) - (width / 2)
                    y:      0
                    width:  ScreenTools.defaultFontPixelWidth * 4
                    height: headingStrip.height
                    visible: Math.abs(delta) < 40

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top:              parent.top
                        width:                    1
                        height:                   parent.height * 0.3
                        color:                    root._lineColor
                    }
                    QGCLabel {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom:           parent.bottom
                        text: {
                            var h = ((tickHeading % 360) + 360) % 360
                            if (h === 0)   return qsTr("N")
                            if (h === 90)  return qsTr("E")
                            if (h === 180) return qsTr("S")
                            if (h === 270) return qsTr("W")
                            return h.toString()
                        }
                        font.pointSize: root._chromeFont
                        color:          root._lineColor
                    }
                }
            }
        }

        // Current heading box
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter:   parent.verticalCenter
            width:                    ScreenTools.defaultFontPixelWidth * 6
            height:                   parent.height * 0.85
            color:                    root._boxBg
            border.color:             root._lineColor
            border.width:             1

            QGCLabel {
                anchors.centerIn: parent
                text:             Math.round(((root._heading % 360) + 360) % 360) + "°"
                color:            root._lineColor
                font.pointSize:   root._chromeFont
            }
        }
    }

    // --------------------------------------------------------- radar strip
    Rectangle {
        id:             radarStrip
        anchors.bottom: parent.bottom
        anchors.left:   parent.left
        anchors.right:  parent.right
        height:         root._radarH
        color:          root._tapeBg

        Row {
            anchors.centerIn: parent
            spacing:          ScreenTools.defaultFontPixelWidth

            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                text:                   qsTr("RDR")
                font.pointSize:         root._chromeFont
                color:                  root._radarColor
            }
            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                text:                   root._radarValid ? root._radarAlt.toFixed(1) + qsTr(" m") : qsTr("--")
                font.pointSize:         root._compact ? root._chromeFont : ScreenTools.defaultFontPointSize
                color:                  root._radarValid ? root._radarColor : root._lineColor
            }
            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                text:                   qsTr("AGL")
                font.pointSize:         ScreenTools.smallFontPointSize
                color:                  root._lineColor
                visible:                root._aglValid && !root._compact
            }
            QGCLabel {
                anchors.verticalCenter: parent.verticalCenter
                text:                   root._agl.toFixed(1) + qsTr(" m")
                font.pointSize:         root._compact ? root._chromeFont : ScreenTools.defaultFontPointSize
                color:                  root._lineColor
            }
        }
    }
}
