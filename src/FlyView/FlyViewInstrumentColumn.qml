import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlightMap

/// The artboard's instrument column: a fixed panel down the right edge holding
/// the flight display and the numbers that go with it.
///
/// Main.dc.html gives it its own zone rather than floating the instruments over
/// the map. That is the point of the five-zone rule -- nothing overlaps, so
/// nothing has to be dodged. The rose and values bar used to sit on top of the
/// map (and, until this week, underneath the obstacle band).
///
/// Layout, top to bottom: a 34px header carrying the pane's name and the swap
/// control, the flight display at 316px, a three-cell rates grid, and the
/// mission block filling whatever is left.
Rectangle {
    id: root

    property var vehicle:           null
    property var missionController: null

    /// Emitted when the pilot asks for the map and the flight display to trade
    /// places, which the artboard labels SWAP MAP.
    signal swapRequested()

    color: qgcPal.window

    QGCPalette { id: qgcPal }

    readonly property color _good:   "#008f2d"
    readonly property color _accent: "#3A9BDC"

    readonly property real _groundSpeed: (vehicle && vehicle.groundSpeed) ? vehicle.groundSpeed.rawValue : NaN
    readonly property real _climbRate:   (vehicle && vehicle.climbRate)   ? vehicle.climbRate.rawValue   : NaN

    /// Height above ground, radar first. The artboard moves AGL here from the
    /// obstacle band so it reads beside the other rates.
    readonly property real _radarAlt: {
        if (!vehicle || !vehicle.namedValueFloats) {
            return NaN
        }
        var e = vehicle.namedValueFloats.values["U3M"]
        if (e && typeof e === "object" && e.value !== undefined && e.value > 0.2) {
            return e.value
        }
        return NaN
    }
    readonly property real _terrainAgl: (vehicle && vehicle.altitudeAboveTerr)
                                            ? vehicle.altitudeAboveTerr.rawValue
                                            : NaN
    readonly property real _agl: !isNaN(_radarAlt) ? _radarAlt : _terrainAgl

    function _fmt(value, digits) {
        return (isNaN(value) || !isFinite(value)) ? "—" : value.toFixed(digits)
    }

    // border-left 2px #c9ccce in the artboard.
    Rectangle {
        anchors.left:   parent.left
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        width:          2
        color:          qgcPal.windowShade
        z:              10
    }

    /// One cell of the rates grid: a small caption over a large number with its
    /// unit trailing, as drawn.
    component RateCell: Rectangle {
        property string caption: ""
        property string value:   "—"
        property string unit:    ""
        property color  valueColor: qgcPal.text

        Layout.fillWidth:       true
        Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 2.4
        color:                  qgcPal.window

        ColumnLayout {
            anchors.fill:           parent
            anchors.margins:        ScreenTools.defaultFontPixelWidth * 0.5
            spacing:                0

            QGCLabel {
                Layout.fillWidth:   true
                text:               caption
                font.pointSize:     ScreenTools.smallFontPointSize
                color:              qgcPal.windowTransparentText
                elide:              Text.ElideRight
            }

            RowLayout {
                Layout.fillWidth:   true
                spacing:            ScreenTools.defaultFontPixelWidth * 0.3

                QGCLabel {
                    Layout.alignment:   Qt.AlignBaseline
                    text:               value
                    font.pointSize:     ScreenTools.defaultFontPointSize * 1.3
                    font.bold:          true
                    color:              valueColor
                }

                QGCLabel {
                    Layout.alignment:   Qt.AlignBaseline
                    text:               unit
                    font.pointSize:     ScreenTools.smallFontPointSize
                    color:              qgcPal.windowTransparentText
                }

                Item { Layout.fillWidth: true }
            }
        }
    }

    ColumnLayout {
        anchors.fill:       parent
        anchors.leftMargin: 2           // clear the border
        spacing:            0

        // ------------------------------------------------------------- header
        Rectangle {
            Layout.fillWidth:       true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.2
            color:                  qgcPal.window

            RowLayout {
                anchors.fill:           parent
                anchors.leftMargin:     ScreenTools.defaultFontPixelWidth * 0.8
                anchors.rightMargin:    ScreenTools.defaultFontPixelWidth * 0.8
                spacing:                ScreenTools.defaultFontPixelWidth

                QGCLabel {
                    text:           qsTr("FLIGHT DISPLAY")
                    font.pointSize: ScreenTools.smallFontPointSize
                    color:          qgcPal.windowTransparentText
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    Layout.preferredWidth:  swapLabel.implicitWidth + (ScreenTools.defaultFontPixelWidth * 1.4)
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.95
                    color:                  swapMouse.pressed ? qgcPal.buttonHighlight : root._accent

                    QGCLabel {
                        id:                 swapLabel
                        anchors.centerIn:   parent
                        text:               qsTr("SWAP MAP")
                        font.pointSize:     ScreenTools.smallFontPointSize
                        color:              "white"
                    }

                    MouseArea {
                        id:             swapMouse
                        anchors.fill:   parent
                        onClicked:      root.swapRequested()
                    }
                }
            }
        }

        Rectangle {
            Layout.fillWidth:       true
            Layout.preferredHeight: 1
            color:                  qgcPal.windowShade
        }

        // ----------------------------------------------------- flight display
        PrimaryFlightDisplay {
            Layout.fillWidth:       true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 11
            radius:                 0
        }

        Rectangle {
            Layout.fillWidth:       true
            Layout.preferredHeight: 1
            color:                  qgcPal.windowShade
        }

        // --------------------------------------------------------- rates grid
        RowLayout {
            Layout.fillWidth:   true
            spacing:            1

            RateCell {
                caption:    qsTr("GROUND SPD")
                value:      root._fmt(root._groundSpeed, 1)
                unit:       qsTr("m/s")
            }

            Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: qgcPal.windowShade }

            RateCell {
                caption:    qsTr("AGL")
                value:      root._fmt(root._agl, 1)
                unit:       qsTr("m")
            }

            Rectangle { Layout.preferredWidth: 1; Layout.fillHeight: true; color: qgcPal.windowShade }

            RateCell {
                caption:    qsTr("VERT SPD")
                value:      (isNaN(root._climbRate) ? "—"
                                : (root._climbRate >= 0 ? "+" : "") + root._climbRate.toFixed(1))
                unit:       qsTr("m/s")
                // Climbing reads green in the artboard; sinking stays neutral
                // rather than alarming, because descending is usually intended.
                valueColor: (!isNaN(root._climbRate) && root._climbRate > 0.05) ? root._good
                                                                                : qgcPal.text
            }
        }

        Rectangle {
            Layout.fillWidth:       true
            Layout.preferredHeight: 1
            color:                  qgcPal.windowShade
        }

        // ------------------------------------------------------ mission block
        MissionProgressBlock {
            Layout.fillWidth:   true
            Layout.fillHeight:  true
            accentColor:        root._accent
            missionController:  root.missionController
        }
    }
}
