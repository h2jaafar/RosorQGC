import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// v3's telemetry card: the four numbers a pilot glances at, bottom-right of
/// the viewport, where DJI's strip and Auterion's panel both put them.
///
/// HEIGHT, HOME, SPEED, CLIMB -- spelled out. DJI's H / D / H.S / V.S work
/// because a decade of pilots learned them; a client reading this bar for the
/// first time has not. Height is above ground, radar first, terrain second,
/// because this aircraft flies low over things.
///
/// The card is one of the reserved slots: nothing else may be placed in the
/// rectangle it occupies, and the map's own controls are inset away from it.
Rectangle {
    id: root

    property var vehicle: null

    /// Fixed footprint so the inset the map is given never moves.
    width:  ScreenTools.defaultFontPixelWidth * 20
    height: ScreenTools.defaultFontPixelHeight * 2.9
    radius: ScreenTools.defaultFontPixelHeight * 0.19
    // #20242a at 0.90: the viewport chrome tone, fixed rather than themed
    // because it sits over imagery in either theme.
    color:  Qt.rgba(0.125, 0.141, 0.165, 0.90)

    readonly property color _fg:      "#ffffff"
    readonly property color _fgDim:   "#c9ccce"
    readonly property color _label:   "#8d959d"

    readonly property bool _vehicleAvailable: vehicle !== null && vehicle !== undefined

    readonly property real _groundSpeed: (_vehicleAvailable && vehicle.groundSpeed) ? vehicle.groundSpeed.rawValue : NaN
    readonly property real _climbRate:   (_vehicleAvailable && vehicle.climbRate)   ? vehicle.climbRate.rawValue   : NaN

    /// Height above ground, radar first. The U300 publishes its downward range
    /// as NAMED_VALUE_FLOAT U3M; the Lua treats anything under 0.2 m as no
    /// reading rather than ground, and so does this.
    readonly property real _radarAlt: {
        if (!_vehicleAvailable || !vehicle.namedValueFloats) {
            return NaN
        }
        var e = vehicle.namedValueFloats.values["U3M"]
        if (e && typeof e === "object" && e.value !== undefined && e.value > 0.2) {
            return e.value
        }
        return NaN
    }
    readonly property real _terrainAgl: (_vehicleAvailable && vehicle.altitudeAboveTerr)
                                            ? vehicle.altitudeAboveTerr.rawValue
                                            : NaN
    readonly property real _agl: !isNaN(_radarAlt) ? _radarAlt : _terrainAgl

    // Distance is NaN until the vehicle has a home. The bearing is turned
    // nose-relative before it is drawn: "which way do I turn" is the question
    // an arrow beside a distance answers.
    readonly property bool _homeKnown:        _vehicleAvailable && !isNaN(vehicle.distanceToHome.rawValue)
    readonly property bool _homeBearingKnown: _homeKnown
                                              && !isNaN(vehicle.headingToHome.rawValue)
                                              && !isNaN(vehicle.heading.rawValue)
    readonly property real _homeRelativeBearing: _homeBearingKnown
                                                 ? (((vehicle.headingToHome.rawValue - vehicle.heading.rawValue) % 360) + 360) % 360
                                                 : 0
    readonly property bool _homeKm: _homeKnown && vehicle.distanceToHome.rawValue >= 1000

    function _fmt(value, digits) {
        return (isNaN(value) || !isFinite(value)) ? "—" : value.toFixed(digits)
    }

    function _homeValue() {
        if (!_homeKnown) {
            return "—"
        }
        var d = vehicle.distanceToHome.rawValue
        return _homeKm ? (d / 1000).toFixed(1) : d.toFixed(0)
    }

    /// One cell: a small caption over a number with its unit on the baseline.
    component Cell: Item {
        property string caption: ""
        property string value:   "—"
        property string unit:    ""
        property bool   showUnit: true

        Layout.fillWidth: true

        implicitHeight: cellColumn.implicitHeight

        ColumnLayout {
            id:             cellColumn
            anchors.left:   parent.left
            anchors.right:  parent.right
            spacing:        0

            QGCLabel {
                text:           caption
                font.pointSize: ScreenTools.smallFontPointSize
                color:          root._label
            }

            RowLayout {
                spacing: ScreenTools.defaultFontPixelWidth * 0.35

                QGCLabel {
                    Layout.alignment:   Qt.AlignBaseline
                    text:               value
                    font.pointSize:     ScreenTools.defaultFontPointSize * 1.35
                    font.bold:          true
                    color:              root._fg
                }

                QGCLabel {
                    Layout.alignment:   Qt.AlignBaseline
                    text:               unit
                    font.pointSize:     ScreenTools.smallFontPointSize
                    color:              root._fgDim
                    visible:            showUnit && unit !== ""
                }

                Item { Layout.fillWidth: true }
            }
        }
    }

    // With nothing connected the card keeps its slot and says so once,
    // instead of four dashes: the layout a new pilot learns is the one they
    // will fly with.
    QGCLabel {
        anchors.centerIn:       parent
        width:                  parent.width - ScreenTools.defaultFontPixelWidth * 2
        horizontalAlignment:    Text.AlignHCenter
        wrapMode:               Text.WordWrap
        text:                   qsTr("Telemetry appears when the aircraft connects")
        font.pointSize:         ScreenTools.smallFontPointSize
        color:                  root._label
        visible:                !root._vehicleAvailable
    }

    GridLayout {
        anchors.fill:       parent
        anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 0.9
        anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 0.9
        anchors.topMargin:  ScreenTools.defaultFontPixelHeight * 0.3
        anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.3
        columns:            2
        rowSpacing:         ScreenTools.defaultFontPixelHeight * 0.1
        columnSpacing:      ScreenTools.defaultFontPixelWidth
        visible:            root._vehicleAvailable

        Cell {
            caption:    qsTr("HEIGHT")
            value:      root._fmt(root._agl, 1)
            unit:       qsTr("m")
            showUnit:   !isNaN(root._agl)
        }

        // The arrow rides in the unit slot so the cell keeps one baseline.
        Item {
            Layout.fillWidth: true
            implicitHeight:   homeColumn.implicitHeight

            ColumnLayout {
                id:             homeColumn
                anchors.left:   parent.left
                anchors.right:  parent.right
                spacing:        0

                QGCLabel {
                    text:           qsTr("HOME")
                    font.pointSize: ScreenTools.smallFontPointSize
                    color:          root._label
                }

                RowLayout {
                    spacing: ScreenTools.defaultFontPixelWidth * 0.35

                    QGCLabel {
                        Layout.alignment:   Qt.AlignBaseline
                        text:               root._homeValue()
                        font.pointSize:     ScreenTools.defaultFontPointSize * 1.35
                        font.bold:          true
                        color:              root._fg
                    }

                    QGCLabel {
                        Layout.alignment:   Qt.AlignBaseline
                        text:               root._homeKm ? qsTr("km") : qsTr("m")
                        font.pointSize:     ScreenTools.smallFontPointSize
                        color:              root._fgDim
                        visible:            root._homeKnown
                    }

                    QGCColoredImage {
                        Layout.alignment:       Qt.AlignVCenter
                        Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 0.6
                        Layout.preferredHeight: Layout.preferredWidth
                        sourceSize.height:      Layout.preferredHeight
                        source:                 "/res/ArrowRight.svg"
                        fillMode:               Image.PreserveAspectFit
                        color:                  root._fg
                        // ArrowRight points right at rest; minus 90 puts 0 deg straight up.
                        rotation:               root._homeRelativeBearing - 90
                        visible:                root._homeBearingKnown
                    }

                    Item { Layout.fillWidth: true }
                }
            }
        }

        Cell {
            caption:    qsTr("SPEED")
            value:      root._fmt(root._groundSpeed, 1)
            unit:       qsTr("m/s")
            showUnit:   !isNaN(root._groundSpeed)
        }

        Cell {
            caption:    qsTr("CLIMB")
            value:      isNaN(root._climbRate) ? "—"
                            : (root._climbRate >= 0 ? "+" : "") + root._climbRate.toFixed(1)
            unit:       qsTr("m/s")
            showUnit:   !isNaN(root._climbRate)
        }
    }
}
