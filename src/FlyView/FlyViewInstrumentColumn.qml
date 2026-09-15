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
    // Nothing leaves the zone, whatever the screen budget turns out to be.
    clip:  true

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
                // "GROUND SPD" is the widest caption and was being cut to
                // "GROUND S..." in a third of the column on the handheld. The
                // artboard spells all three out, so the caption shrinks to fit
                // before it is allowed to elide.
                fontSizeMode:       Text.HorizontalFit
                minimumPointSize:   ScreenTools.smallFontPointSize * 0.75
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
        //
        // 316 of 800 in the artboard, but that assumes the artboard's own
        // budget. The handheld gives this column roughly 410px once the
        // toolbar, band and status bar have taken theirs, and a fixed 316 here
        // pushed the mission block straight out of the bottom of the column and
        // over the obstacle band. The display is the one item that reads fine
        // smaller, so it takes the squeeze.
        PrimaryFlightDisplay {
            Layout.fillWidth:       true
            Layout.fillHeight:      true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 11
            Layout.minimumHeight:   ScreenTools.defaultFontPixelHeight * 6
            radius:                 0
            // The heading strip is this zone's compass, so it is not optional here. Left to
            // its own height rule the display drops it: the column squeezes it to about 5.7
            // font-heights, under the threshold meant for the PipView thumbnail, and the
            // strip went with it. It costs the column nothing -- it is drawn inside the
            // display, so only the horizon gives up the room.
            showHeadingStrip:       true
            // Same gate, same cause: the roll scale, the roll pointer and the roll/pitch
            // numerals are what the artboard's horizon note asks for, and the column was
            // hiding all four. The side tapes stay off -- the rates grid directly below
            // already reads ground speed, AGL and vertical speed.
            showAttitudeChrome:     true
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
                // "AGL" is an aviation abbreviation; a surveyor reads height above
                // ground. The caption shrinks to fit rather than eliding, so the
                // longer label is safe in a third of the column.
                caption:    qsTr("ABOVE GROUND")
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
            Layout.fillWidth:       true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 4
            accentColor:            root._accent
            missionController:      root.missionController
        }
    }
}
