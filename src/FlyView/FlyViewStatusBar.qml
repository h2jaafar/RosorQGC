import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// Zone 1 of Main.dc.html: the fly view's top status bar.
///
/// The artboard gives the top 76px of 800 to four things and nothing else -- an
/// armed/mode chip, the three numbers a pilot checks before and during a flight
/// (battery, GPS/RTK, EKF), and a standing alert panel. It replaces the stock
/// QGC toolbar, whose indicator row packed a dozen competing items into the
/// same strip and left the important three the same size as the rest.
///
/// The readouts are deliberately the same three the removed CriticalStatusBar
/// carried along the bottom of the window. The artboard has no zone for that
/// strip, so its content moves here rather than being shown twice.
Item {
    id:     root
    width:  parent.width
    // 76 of 800 in the artboard.
    height: ScreenTools.defaultFontPixelHeight * 2.6

    /// Emitted when the pilot taps the alert panel to read the full list.
    signal reviewVehicleMessages()

    /// Show a critical vehicle message in the alert panel.
    function showVehicleMessage(message) {
        alertBanner.show(message)
    }

    /// Open the vehicle's overall-status drawer, where the full message list is.
    function dropMainStatusIndicatorTool() {
        statusDrawerHost.dropMainStatusIndicator()
    }

    readonly property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    readonly property var _rtk:           QGroundControl.gpsRtk

    readonly property bool _vehicleAvailable: _activeVehicle !== null && _activeVehicle !== undefined

    // Design palette, as in the obstacle band: surfaces and text come from
    // qgcPal so the bar follows the Indoor/Outdoor theme, while the semantic
    // accents are fixed -- they mean danger / good / alert wherever they appear.
    readonly property color _danger: "#b52b2b"
    readonly property color _good:   "#008f2d"
    readonly property color _alert:  "#eecc44"

    // The artboard's label grey against either theme's window colour.
    readonly property real _labelOpacity: 0.65

    QGCPalette { id: qgcPal }

    Rectangle {
        anchors.fill:   parent
        color:          qgcPal.window
    }

    // Border-bottom 2px #c9ccce in the artboard.
    Rectangle {
        anchors.left:   parent.left
        anchors.right:  parent.right
        anchors.bottom: parent.bottom
        height:         2
        color:          qgcPal.windowShade
    }

    // ---------------------------------------------------------------- helpers
    //
    // Severity is the same 0/1/2 scale the removed status bar used: 0 good,
    // 1 warn, 2 bad. Unknown reads neutral rather than alarming, because a bar
    // that shouts on the bench teaches the pilot to ignore it.

    function _severityColor(severity) {
        if (severity === 2) {
            return root._danger
        }
        if (severity === 1) {
            return root._alert
        }
        return root._good
    }

    function _vehicleArmedOrInFlight() {
        return _vehicleAvailable && (_activeVehicle.armed || _activeVehicle.flying || _activeVehicle.landing)
    }

    /// The lowest battery of the pack, by percent when every battery reports one
    /// and by voltage otherwise. A pack is only as good as its worst cell.
    function _selectBattery() {
        if (!_vehicleAvailable || !_activeVehicle.batteries || _activeVehicle.batteries.count === 0) {
            return null
        }
        var lowest = _activeVehicle.batteries.get(0)
        var usePercent = true
        for (var i = 0; i < _activeVehicle.batteries.count; i++) {
            if (isNaN(_activeVehicle.batteries.get(i).percentRemaining.rawValue)) {
                usePercent = false
                break
            }
        }
        for (var j = 1; j < _activeVehicle.batteries.count; j++) {
            var battery = _activeVehicle.batteries.get(j)
            if (usePercent) {
                if (battery.percentRemaining.rawValue < lowest.percentRemaining.rawValue) {
                    lowest = battery
                }
            } else if (!isNaN(battery.voltage.rawValue) && battery.voltage.rawValue < lowest.voltage.rawValue) {
                lowest = battery
            }
        }
        return lowest
    }

    property var _battery: _selectBattery()

    Connections {
        target: QGroundControl.multiVehicleManager
        ignoreUnknownSignals: true
        function onActiveVehicleChanged() { root._battery = root._selectBattery() }
    }

    readonly property bool _batteryVoltageKnown: _battery !== null && !isNaN(_battery.voltage.rawValue)
    readonly property bool _batteryPercentKnown: _battery !== null && !isNaN(_battery.percentRemaining.rawValue)

    function _gpsAvailable() {
        return _vehicleAvailable && _activeVehicle.gps && _activeVehicle.gps.telemetryAvailable
    }

    function _gpsLockGood() {
        return _gpsAvailable() && _activeVehicle.gps.lock.rawValue >= 3
    }

    function _gpsPoorHdop() {
        return _gpsAvailable() && !isNaN(_activeVehicle.gps.hdop.rawValue) && _activeVehicle.gps.hdop.rawValue > 2.0
    }

    function _gpsSeverity() {
        if (!_gpsAvailable()) {
            return _vehicleAvailable ? (_vehicleArmedOrInFlight() ? 2 : 1) : 0
        }
        if (_gpsLockGood()) {
            return _gpsPoorHdop() ? 1 : 0
        }
        return _vehicleArmedOrInFlight() ? 2 : 1
    }

    /// The artboard puts the fix quality on the big line and the satellite count
    /// beside it, so RTK -- the thing that decides whether a survey is usable --
    /// is what the eye lands on.
    function _gpsPrimaryText() {
        if (!_gpsAvailable()) {
            return qsTr("—")
        }
        if (_rtk && _rtk.connected.value) {
            return qsTr("RTK")
        }
        return _activeVehicle.gps.lock.enumStringValue
    }

    function _satCount() {
        if (!_vehicleAvailable || !_activeVehicle.gps) {
            return -1
        }
        var n = _activeVehicle.gps.count.rawValue
        return (n === undefined || isNaN(n)) ? -1 : n
    }

    function _satsText() {
        var n = _satCount()
        return n < 0 ? qsTr("— sats") : qsTr("%1 sats").arg(n)
    }

    // EKF health is not a one-liner -- two MAVLink sources describe the filter
    // and five subsystems have to be reconciled -- so it has its own component
    // rather than being re-derived here.
    VehicleEkfHealth {
        id:      ekfHealth
        vehicle: root._activeVehicle
    }

    // ------------------------------------------------------------- mode chip
    //
    // Artboard: a 116px cell, green when armed, carrying the arm state over the
    // flight mode.
    //
    // It also carries the application menu. The artboard draws no tool button
    // anywhere in its five zones, but removing the stock toolbar removes the
    // only route to Comm Links, Settings and the Plan view -- on the handheld
    // that leaves no way to set up the datalink at all. Putting the menu on the
    // chip keeps one entry point without inventing a zone the drawing does not
    // have. This is the one interaction here the artboard does not specify.
    Rectangle {
        id:                     modeChip
        anchors.left:           parent.left
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        anchors.bottomMargin:   2       // clear the bar's bottom border
        // 116 of 1280 in the artboard, but only as a floor. The artboard only
        // ever draws "ARMED"; "DISARMED" and "NO LINK" are wider than 116px at
        // this size and were being centred out past the left edge of the screen,
        // so the chip grows to whatever the longest state actually needs.
        width:                  Math.max(ScreenTools.defaultFontPixelWidth * 8,
                                         chipColumn.width + ScreenTools.defaultFontPixelWidth * 1.5)
        color:                  root._vehicleArmedOrInFlight() ? root._good : qgcPal.windowShade

        readonly property color _fg: root._vehicleArmedOrInFlight() ? "white" : qgcPal.text

        Column {
            id:                 chipColumn
            anchors.centerIn:   parent
            spacing:            2

            QGCLabel {
                anchors.horizontalCenter:   parent.horizontalCenter
                text:                       root._vehicleAvailable
                                                ? (root._activeVehicle.armed ? qsTr("ARMED") : qsTr("DISARMED"))
                                                : qsTr("NO LINK")
                color:                      modeChip._fg
                font.pointSize:             ScreenTools.largeFontPointSize * 0.95
                font.bold:                  true
            }

            QGCLabel {
                anchors.horizontalCenter:   parent.horizontalCenter
                text:                       root._vehicleAvailable ? root._activeVehicle.flightMode : ""
                color:                      modeChip._fg
                font.pointSize:             ScreenTools.smallFontPointSize
                visible:                    text !== ""
            }
        }

        QGCMouseArea {
            anchors.fill:   parent
            onClicked:      mainWindow.showToolSelectDialog()
        }
    }

    // --------------------------------------------------------------- readouts
    //
    // Artboard: battery, GPS/RTK and EKF across the middle with hairline
    // dividers, each a small label over one large value.
    Row {
        id:                     readouts
        anchors.left:           modeChip.right
        anchors.right:          alertPanel.visible ? alertPanel.left : parent.right
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        anchors.bottomMargin:   2
        anchors.leftMargin:     ScreenTools.defaultFontPixelWidth * 1.8
        anchors.rightMargin:    ScreenTools.defaultFontPixelWidth * 1.8
        spacing:                ScreenTools.defaultFontPixelWidth * 2.3

        // ------------------------------------------------------------ battery
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing:                1

            QGCLabel {
                text:           qsTr("BATTERY")
                color:          qgcPal.text
                opacity:        root._labelOpacity
                font.pointSize: ScreenTools.smallFontPointSize
            }

            Row {
                spacing: ScreenTools.defaultFontPixelWidth * 0.4

                QGCLabel {
                    text:           root._batteryVoltageKnown
                                        ? root._battery.voltage.rawValue.toFixed(1)
                                        : qsTr("—")
                    color:          qgcPal.text
                    font.pointSize: ScreenTools.largeFontPointSize * 1.1
                    font.bold:      true
                }

                QGCLabel {
                    anchors.bottom:         parent.bottom
                    anchors.bottomMargin:   ScreenTools.defaultFontPixelHeight * 0.1
                    text:                   qsTr("V")
                    color:                  qgcPal.text
                    opacity:                root._labelOpacity
                    font.pointSize:         ScreenTools.defaultFontPointSize
                    visible:                root._batteryVoltageKnown
                }

                QGCLabel {
                    anchors.bottom:         parent.bottom
                    anchors.bottomMargin:   ScreenTools.defaultFontPixelHeight * 0.1
                    text:                   root._batteryPercentKnown
                                                ? qsTr("%1%").arg(root._battery.percentRemaining.rawValue.toFixed(0))
                                                : ""
                    color:                  qgcPal.text
                    opacity:                root._labelOpacity
                    font.pointSize:         ScreenTools.defaultFontPointSize
                    visible:                text !== ""
                }
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width:                  1
            height:                 readouts.height * 0.6
            color:                  qgcPal.windowShade
        }

        // ------------------------------------------------------------ GPS/RTK
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing:                1

            QGCLabel {
                text:           qsTr("GPS / RTK")
                color:          qgcPal.text
                opacity:        root._labelOpacity
                font.pointSize: ScreenTools.smallFontPointSize
            }

            Row {
                spacing: ScreenTools.defaultFontPixelWidth * 0.4

                QGCLabel {
                    text:           root._gpsPrimaryText()
                    // Same rule as EKF: with no vehicle and no fix there is
                    // nothing to be green about, so unknown stays neutral
                    // rather than reading as a good lock on the bench.
                    color:          root._gpsAvailable() ? root._severityColor(root._gpsSeverity())
                                                         : qgcPal.text
                    font.pointSize: ScreenTools.largeFontPointSize * 1.1
                    font.bold:      true
                }

                QGCLabel {
                    anchors.bottom:         parent.bottom
                    anchors.bottomMargin:   ScreenTools.defaultFontPixelHeight * 0.1
                    text:                   root._satsText()
                    color:                  qgcPal.text
                    opacity:                root._labelOpacity
                    font.pointSize:         ScreenTools.defaultFontPointSize
                }
            }
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width:                  1
            height:                 readouts.height * 0.6
            color:                  qgcPal.windowShade
        }

        // ---------------------------------------------------------------- EKF
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing:                1

            QGCLabel {
                // The artboard labels this cell EKF. Nobody outside the autopilot
                // community knows what an EKF is, and the value it reports -- OK,
                // WARN, BAD -- is the health of the position estimate, so that is
                // what the cell is called. The filter is still what it reads.
                text:           qsTr("POSITION")
                color:          qgcPal.text
                opacity:        root._labelOpacity
                font.pointSize: ScreenTools.smallFontPointSize
            }

            QGCLabel {
                text:           ekfHealth.text
                // Unknown stays in the ordinary text colour. Green would claim
                // the filter is healthy when nothing has reported yet.
                color:          ekfHealth.known ? root._severityColor(ekfHealth.severity)
                                                : qgcPal.text
                font.pointSize: ScreenTools.largeFontPointSize * 1.1
                font.bold:      true
            }
        }
    }

    // ----------------------------------------------------------- alert panel
    //
    // Artboard: a 300px amber cell holding the newest standing message and a
    // count of the ones behind it. VehicleMessageBanner already does the
    // folding, counting, de-duplication and avoidance classification, so the
    // zone supplies the space and the banner supplies the behaviour.
    Item {
        id:                     alertPanel
        anchors.right:          parent.right
        anchors.top:            parent.top
        anchors.bottom:         parent.bottom
        anchors.bottomMargin:   2
        // 300 of 1280 in the artboard.
        width:                  ScreenTools.defaultFontPixelWidth * 20.7
        visible:                alertBanner.hasMessage

        // border-left 2px #c9ccce in the artboard.
        Rectangle {
            anchors.left:   parent.left
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            width:          2
            color:          qgcPal.windowShade
        }

        VehicleMessageBanner {
            id:                 alertBanner
            anchors.fill:       parent
            anchors.leftMargin: 2
            compact:            true
            onReviewRequested:  root.reviewVehicleMessages()
        }
    }

    // "Tap to review" opens the same overall-status drawer the stock toolbar's
    // main status indicator owned. The indicator itself is not drawn -- the
    // artboard has no cell for it -- but it stays instantiated over the alert
    // panel so the drawer has a control to anchor under, and the review path
    // stays the proven one rather than a second message list.
    MainStatusIndicator {
        id:             statusDrawerHost
        anchors.fill:   alertPanel
        visible:        false
    }
}
