import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// v3's status bar: a translucent strip across the top of the viewport, the
/// shape DJI Fly, DJI Pilot 2, Auterion Mission Control and Skydio all use.
///
/// Left to right, the order a pilot needs: the state word as a pill (NO LINK,
/// COMMS LOST, READY, NOT READY, ARMED, FLYING, LANDING), then ONE status
/// sentence -- the newest standing vehicle message when there is one, in
/// amber, otherwise a calm line saying what the aircraft is doing -- then, on
/// the right, battery with minutes remaining, GNSS fix and satellites, and
/// the application menu. Nothing else. The numbers a pilot glances at in
/// flight live in the telemetry card; the obstacle readout lives in the nav
/// card; this bar is for state.
///
/// Filled green is reserved for armed. A disarmed aircraft that is READY shows
/// the word in green on the neutral pill, not a green pill: a green block is
/// what means the motors can turn, and that is the one thing a pilot must
/// never mistake.
Item {
    id:     root
    width:  parent.width
    // 56 of 800 in the artboard.
    height: ScreenTools.defaultFontPixelHeight * 1.75

    /// The fly view's mission controller, for the calm sentence's progress.
    property var missionController: null

    /// Emitted when the pilot taps the alert to read the full list.
    signal reviewVehicleMessages()

    /// Show a critical vehicle message in the status sentence slot.
    function showVehicleMessage(message) {
        alertBanner.show(message)
    }

    /// Open the vehicle's overall-status drawer, where the full message list is.
    function dropMainStatusIndicatorTool() {
        statusDrawerHost.dropMainStatusIndicator()
    }

    // MainStatusIndicator writes this from its own mainStatusText() -- it was
    // declared by the stock toolbar that used to host it, and has been an
    // "Invalid write to global property" on every launch since that toolbar
    // went. A component resolves ids and properties through the context that
    // created it, so declaring it on the host is what the indicator expects.
    // Nothing here reads it.
    property color _mainStatusBGColor: qgcPal.brandingPurple

    readonly property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle
    readonly property var _rtk:           QGroundControl.gpsRtk

    readonly property bool _vehicleAvailable: _activeVehicle !== null && _activeVehicle !== undefined

    // Semantic accents are fixed -- they mean danger / good / alert wherever
    // they appear. The chrome tone is #20242a at 0.90, fixed rather than
    // themed because the bar sits over imagery in either theme.
    readonly property color _danger:  "#b52b2b"
    readonly property color _good:    "#008f2d"
    readonly property color _alert:   "#eecc44"
    readonly property color _chrome:  Qt.rgba(0.125, 0.141, 0.165, 0.90)
    readonly property color _neutral: Qt.rgba(1, 1, 1, 0.14)
    readonly property color _fg:      "#ffffff"
    readonly property color _fgDim:   "#c9ccce"

    QGCPalette { id: qgcPal }

    Rectangle {
        anchors.fill:   parent
        color:          root._chrome
    }

    // ---------------------------------------------------------------- helpers
    //
    // Severity is the 0/1/2 scale the removed status bar used: 0 good, 1 warn,
    // 2 bad. Unknown reads neutral rather than alarming, because a bar that
    // shouts on the bench teaches the pilot to ignore it.

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

    // ------------------------------------------------------------- readiness
    //
    // The branching mirrors MainStatusIndicator so the pill and the status
    // drawer never disagree; the words are shorter and upper case because the
    // pill is small. What is reported is the autopilot's own judgement, not a
    // synthesis of GPS and EKF done here.

    // MainStatusIndicator (the hidden drawer host at the bottom of this file)
    // resolves this name from its host document, as it did from the stock
    // toolbar. Same fact as _commsLost, under the name the indicator expects.
    readonly property bool _communicationLost:     _commsLost
    readonly property bool _commsLost:             _vehicleAvailable
                                                   && _activeVehicle.vehicleLinkManager
                                                   && _activeVehicle.vehicleLinkManager.communicationLost
    readonly property bool _healthChecksSupported: _vehicleAvailable
                                                   && _activeVehicle.healthAndArmingCheckReport
                                                   && _activeVehicle.healthAndArmingCheckReport.supported

    /// 0 neutral, 1 good, 2 attention, 3 danger.
    function _readinessTone() {
        if (!_vehicleAvailable) {
            return 0
        }
        if (_commsLost) {
            return 3
        }
        if (_healthChecksSupported) {
            var report = _activeVehicle.healthAndArmingCheckReport
            if (!report.canArm) {
                return 3
            }
            return report.hasWarningsOrErrors ? 2 : 1
        }
        if (_activeVehicle.armed) {
            return 1
        }
        if (_activeVehicle.readyToFlyAvailable) {
            return _activeVehicle.readyToFly ? 1 : 2
        }
        return (_activeVehicle.allSensorsHealthy && _activeVehicle.autopilotPlugin.setupComplete) ? 1 : 2
    }

    function _readinessText() {
        if (!_vehicleAvailable) {
            return qsTr("NO LINK")
        }
        if (_commsLost) {
            return qsTr("COMMS LOST")
        }
        if (_activeVehicle.armed) {
            if (_activeVehicle.flying) {
                return qsTr("FLYING")
            }
            if (_activeVehicle.landing) {
                return qsTr("LANDING")
            }
            return qsTr("ARMED")
        }
        if (_healthChecksSupported) {
            return _activeVehicle.healthAndArmingCheckReport.canArm ? qsTr("READY") : qsTr("NOT READY")
        }
        if (_activeVehicle.readyToFlyAvailable) {
            return _activeVehicle.readyToFly ? qsTr("READY") : qsTr("NOT READY")
        }
        return (_activeVehicle.allSensorsHealthy && _activeVehicle.autopilotPlugin.setupComplete)
                   ? qsTr("READY") : qsTr("NOT READY")
    }

    // --------------------------------------------------------------- battery
    //
    /// The lowest battery of the pack, by percent when every battery reports
    /// one and by voltage otherwise. A pack is only as good as its worst cell.
    ///
    /// A plain binding, on purpose. It used to be re-assigned imperatively from
    /// an onActiveVehicleChanged handler, and that assignment broke the binding
    /// at the moment the vehicle appeared with zero batteries reported -- so
    /// the cell stayed blank for the whole flight. Verified on the bench
    /// 2026-09-15 with a log the stock indicator read 12.6 V from. As a
    /// binding it re-evaluates when batteries.count changes.
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

    readonly property var _battery: _selectBattery()

    readonly property bool _batteryVoltageKnown: _battery !== null && !isNaN(_battery.voltage.rawValue)
    readonly property bool _batteryPercentKnown: _battery !== null && !isNaN(_battery.percentRemaining.rawValue)
    // Reported in seconds by the autopilot when it estimates one at all; NaN and 0 both mean no estimate.
    readonly property bool _batteryTimeKnown:    _battery !== null && !isNaN(_battery.timeRemaining.rawValue)
                                                 && _battery.timeRemaining.rawValue > 0

    function _batteryMainText() {
        if (_batteryPercentKnown) {
            return qsTr("%1%").arg(_battery.percentRemaining.rawValue.toFixed(0))
        }
        if (_batteryVoltageKnown) {
            return qsTr("%1 V").arg(_battery.voltage.rawValue.toFixed(1))
        }
        return qsTr("—")
    }

    function _batteryTimeText() {
        return qsTr("%1 min").arg(Math.round(_battery.timeRemaining.rawValue / 60))
    }

    // ------------------------------------------------------------------ GNSS

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

    /// RTK -- the thing that decides whether a survey is usable -- is what the
    /// eye lands on; the fix type otherwise. Short words: the stock enum string
    /// for fix 6 is "3D RTK GPS Lock (fixed)", which on the bench ate a third
    /// of the bar and pushed the message banner off it.
    function _gpsPrimaryText() {
        if (!_gpsAvailable()) {
            return qsTr("—")
        }
        switch (_activeVehicle.gps.lock.rawValue) {
        case 6:  return qsTr("RTK Fixed")
        case 5:  return qsTr("RTK Float")
        case 4:  return qsTr("DGPS")
        case 3:  return qsTr("3D Lock")
        case 2:  return qsTr("2D Lock")
        case 1:
        case 0:  return qsTr("No fix")
        }
        if (_rtk && _rtk.connected.value) {
            return qsTr("RTK")
        }
        return _activeVehicle.gps.lock.enumStringValue
    }

    function _satsText() {
        if (!_vehicleAvailable || !_activeVehicle.gps) {
            return ""
        }
        var n = _activeVehicle.gps.count.rawValue
        return (n === undefined || isNaN(n)) ? "" : qsTr("%1 sats").arg(n)
    }

    // EKF health is not a one-liner -- two MAVLink sources describe the filter
    // and five subsystems have to be reconciled -- so it has its own component.
    // The bar has no cell for it; it enters the calm sentence when degraded.
    VehicleEkfHealth {
        id:      ekfHealth
        vehicle: root._activeVehicle
    }

    // ---------------------------------------------------------- the sentence
    //
    /// What the aircraft is doing, in one line, when no vehicle message is
    /// standing. This is DJI's "Ready to Go" and Auterion's status text: the
    /// single most stranger-friendly instrument any of them has.
    readonly property int  _missionCount:   missionController ? missionController.missionItemCount    : 0
    readonly property int  _missionCurrent: missionController ? missionController.currentMissionIndex : 0
    readonly property real _missionTimeS:   missionController ? missionController.missionTime          : NaN

    function _missionTimeText() {
        if (isNaN(_missionTimeS) || !isFinite(_missionTimeS) || _missionTimeS <= 0) {
            return ""
        }
        var mins = Math.floor(_missionTimeS / 60)
        var secs = Math.floor(_missionTimeS % 60)
        return qsTr("%1:%2 left").arg(mins).arg(secs < 10 ? "0" + secs : secs)
    }

    function _positionSuffix() {
        if (!ekfHealth.known || ekfHealth.severity === 0) {
            return ""
        }
        return ekfHealth.severity === 2 ? qsTr(" · position BAD") : qsTr(" · position WARN")
    }

    function _calmSentence() {
        if (!_vehicleAvailable) {
            return qsTr("No aircraft connected")
        }
        var mode = _activeVehicle.flightMode
        if (_activeVehicle.flying || _activeVehicle.landing) {
            if (_missionCount > 0 && _activeVehicle.flightMode === "Auto") {
                var t = _missionTimeText()
                return qsTr("On mission · WP %1 of %2").arg(_missionCurrent).arg(_missionCount)
                       + (t !== "" ? " · " + t : "") + _positionSuffix()
            }
            return qsTr("Flying · %1").arg(mode) + _positionSuffix()
        }
        if (_activeVehicle.armed) {
            return qsTr("Armed · %1").arg(mode) + _positionSuffix()
        }
        if (_readinessTone() === 1) {
            return qsTr("Ready to take off") + _positionSuffix()
        }
        return qsTr("Not ready · %1").arg(mode) + _positionSuffix()
    }

    // -------------------------------------------------------------- left side
    Row {
        id:                     leftCluster
        anchors.left:           parent.left
        anchors.leftMargin:     ScreenTools.defaultFontPixelWidth
        anchors.verticalCenter: parent.verticalCenter
        spacing:                ScreenTools.defaultFontPixelWidth * 0.9

        // The state pill. It also carries the application menu: removing the
        // stock toolbar removed the only route to Comm Links, Settings and the
        // Plan view, and on the handheld that leaves no way to set up the
        // datalink at all. One entry point, on the thing you look at first.
        Rectangle {
            id:     statePill
            height: ScreenTools.defaultFontPixelHeight * 0.9
            width:  stateLabel.implicitWidth + ScreenTools.defaultFontPixelWidth * 1.6
            radius: ScreenTools.defaultFontPixelHeight * 0.12

            readonly property int _tone: root._readinessTone()

            // Fill only for states that demand it. Danger and attention fill in
            // any arm state; green fills only when armed. Everything else is the
            // neutral pill, and READY is carried by the word's colour instead.
            color: _tone === 3 ? root._danger
                   : _tone === 2 ? root._alert
                   : (root._vehicleArmedOrInFlight() ? root._good : root._neutral)

            readonly property color _fgColor: _tone === 2 ? "#000000"
                                              : (_tone === 1 && !root._vehicleArmedOrInFlight()) ? root._good
                                              : root._fg

            QGCLabel {
                id:                 stateLabel
                anchors.centerIn:   parent
                text:               root._readinessText()
                font.pointSize:     ScreenTools.defaultFontPointSize
                font.bold:          true
                color:              statePill._fgColor
            }

            QGCMouseArea {
                anchors.fill:   parent
                onClicked:      mainWindow.showToolSelectDialog()
            }
        }

        // The sentence slot: the newest standing vehicle message when there is
        // one -- VehicleMessageBanner does the folding, counting and avoidance
        // classification, and draws itself amber -- otherwise the calm line.
        Item {
            id:     sentenceSlot
            height: ScreenTools.defaultFontPixelHeight * 0.9
            width:  alertBanner.hasMessage ? ScreenTools.defaultFontPixelWidth * 28
                                           : calmLabel.implicitWidth

            VehicleMessageBanner {
                id:                 alertBanner
                anchors.fill:       parent
                compact:            true
                visible:            hasMessage
                onReviewRequested:  root.reviewVehicleMessages()
            }

            QGCLabel {
                id:                     calmLabel
                anchors.verticalCenter: parent.verticalCenter
                text:                   root._calmSentence()
                font.pointSize:         ScreenTools.defaultFontPointSize
                color:                  root._fgDim
                visible:                !alertBanner.hasMessage
            }
        }
    }

    // ------------------------------------------------------------- right side
    Row {
        id:                     rightCluster
        anchors.right:          parent.right
        anchors.rightMargin:    ScreenTools.defaultFontPixelWidth
        anchors.verticalCenter: parent.verticalCenter
        spacing:                ScreenTools.defaultFontPixelWidth * 1.6

        // Battery: percent leads, minutes beside it when the autopilot
        // estimates one. Volts only when there is no percent.
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing:                ScreenTools.defaultFontPixelWidth * 0.4
            visible:                root._vehicleAvailable

            QGCLabel {
                anchors.baseline:   batteryTime.baseline
                text:               root._batteryMainText()
                font.pointSize:     ScreenTools.defaultFontPointSize * 1.1
                font.bold:          true
                color:              root._fg
            }

            QGCLabel {
                id:                 batteryTime
                anchors.verticalCenter: parent.verticalCenter
                text:               root._batteryTimeKnown ? root._batteryTimeText() : ""
                font.pointSize:     ScreenTools.smallFontPointSize
                color:              root._fgDim
                visible:            text !== ""
            }
        }

        // GNSS: the fix type in its severity colour, satellites beside it.
        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing:                ScreenTools.defaultFontPixelWidth * 0.4
            visible:                root._vehicleAvailable

            QGCLabel {
                anchors.baseline:   satsLabel.baseline
                text:               root._gpsPrimaryText()
                font.pointSize:     ScreenTools.defaultFontPointSize * 1.1
                font.bold:          true
                // With no vehicle and no fix there is nothing to be green about,
                // so unknown stays neutral rather than reading as a good lock.
                color:              root._gpsAvailable() ? root._severityColor(root._gpsSeverity()) : root._fg
            }

            QGCLabel {
                id:                 satsLabel
                anchors.verticalCenter: parent.verticalCenter
                text:               root._satsText()
                font.pointSize:     ScreenTools.smallFontPointSize
                color:              root._fgDim
                visible:            text !== ""
            }
        }

        // The application menu, where every one of the reference apps puts it.
        Item {
            width:  ScreenTools.defaultFontPixelHeight * 1.2
            height: ScreenTools.defaultFontPixelHeight * 1.2
            anchors.verticalCenter: parent.verticalCenter

            QGCColoredImage {
                anchors.centerIn:   parent
                width:              ScreenTools.defaultFontPixelHeight * 0.8
                height:             width
                sourceSize.height:  height
                source:             "/res/gear-white.svg"
                fillMode:           Image.PreserveAspectFit
                color:              root._fg
            }

            QGCMouseArea {
                anchors.fill:   parent
                onClicked:      mainWindow.showToolSelectDialog()
            }
        }
    }

    // "Tap to review" opens the same overall-status drawer the stock toolbar's
    // main status indicator owned. The indicator itself is not drawn, but it
    // stays instantiated over the left cluster (a sibling -- anchors cannot
    // reach the nested sentence slot) so the drawer has a control to anchor
    // under, and the review path stays the proven one.
    MainStatusIndicator {
        id:             statusDrawerHost
        anchors.fill:   leftCluster
        visible:        false
    }
}
