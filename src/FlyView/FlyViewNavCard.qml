import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

/// v3's navigation display: bottom-left of the viewport, where DJI Pilot 2
/// and Auterion both put the aircraft-centred view. This is where the radar
/// lives now -- the closest-obstacle distance, the stop trigger, and (from the
/// next stage) a heading ring with the forward sensing sector and a vertical
/// obstacle bar, in the idiom every pilot already reads.
///
/// The logic here moved verbatim from the obstacle band: the O_C1M / U3M /
/// O_HZ named floats, the RADAR_FWD_M trigger and its hysteresis. The band
/// carried the same numbers as a full-width strip; the card carries them in a
/// reserved slot the map's own controls are inset away from. The along-track
/// profile the band drew is one tap away, on the card.
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

    // Design palette. Surfaces are the chrome tone above; the semantic accents
    // are fixed -- they mean danger / good / alert / action wherever they appear.
    readonly property color _danger:  "#b52b2b"
    readonly property color _good:    "#008f2d"
    readonly property color _alert:   "#eecc44"
    readonly property color _accent:  "#3A9BDC"
    readonly property color _fg:      "#ffffff"
    readonly property color _fgDim:   "#c9ccce"
    readonly property color _label:   "#8d959d"

    readonly property bool _vehicleAvailable: vehicle !== null && vehicle !== undefined

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
        if (!radarParams.haveTrigger || radarParams.avoidEnabled === false || isNaN(root._closest)) {
            root.insideTrigger = false
        } else if (root.insideTrigger) {
            if (root._closest > radarParams.clearM) {
                root.insideTrigger = false
            }
        } else if (root._closest <= radarParams.fwdTrigM) {
            root.insideTrigger = true
        }
    }

    on_ClosestChanged: root._updateInsideTrigger()

    Connections {
        target: radarParams
        ignoreUnknownSignals: true
        function onFwdTrigMChanged()     { root._updateInsideTrigger() }
        function onHaveTriggerChanged()  { root._updateInsideTrigger() }
        function onAvoidEnabledChanged() { root._updateInsideTrigger() }
    }

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

    // The heading ring, sensing sector and vertical bar land here in the next
    // stage. Until then the card carries the number and the state, as the band did.
    ColumnLayout {
        anchors.left:           parent.left
        anchors.right:          parent.right
        anchors.bottom:         parent.bottom
        anchors.leftMargin:     ScreenTools.defaultFontPixelWidth * 0.8
        anchors.rightMargin:    ScreenTools.defaultFontPixelWidth * 0.8
        anchors.bottomMargin:   ScreenTools.defaultFontPixelHeight * 0.3
        spacing:                ScreenTools.defaultFontPixelHeight * 0.2

        QGCLabel {
            text:           qsTr("CLOSEST OBSTACLE")
            font.pointSize: ScreenTools.smallFontPointSize
            color:          root._label
        }

        RowLayout {
            Layout.fillWidth:   true
            spacing:            ScreenTools.defaultFontPixelWidth * 0.4

            QGCLabel {
                Layout.alignment:   Qt.AlignBaseline
                text:               isNaN(root._closest) ? "—" : root._closest.toFixed(1)
                font.pointSize:     ScreenTools.largeFontPointSize * 1.5
                font.bold:          true
                color:              root.insideTrigger ? root._danger : root._fg
            }

            QGCLabel {
                Layout.alignment:   Qt.AlignBaseline
                text:               qsTr("m")
                font.pointSize:     ScreenTools.defaultFontPointSize
                color:              root._fgDim
                visible:            !isNaN(root._closest)
            }

            Item { Layout.fillWidth: true }

            // Sized to the cell it reads as a state, not a label.
            Rectangle {
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.9
                Layout.preferredWidth:  triggerLabel.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.4
                Layout.alignment:       Qt.AlignVCenter
                radius:                 ScreenTools.defaultFontPixelHeight * 0.12
                color:                  root.insideTrigger ? root._danger : root._good
                visible:                !isNaN(root._closest) && radarParams.haveTrigger

                QGCLabel {
                    id:                 triggerLabel
                    anchors.centerIn:   parent
                    text:               root.insideTrigger ? qsTr("INSIDE TRIGGER") : qsTr("CLEAR")
                    font.pointSize:     ScreenTools.smallFontPointSize
                    font.bold:          true
                    color:              "white"
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
