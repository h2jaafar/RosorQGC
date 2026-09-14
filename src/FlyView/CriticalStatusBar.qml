import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Rectangle {
    id:                 root
    // Must account for every band the rows actually occupy: the top margin
    // above the first row and the padding below the last one as well as the
    // rows themselves. Leaving the top margin out made the bar shorter than its
    // own content, and because it is anchored to the bottom of the window the
    // overflow fell off the screen edge -- on the 7" handheld that clipped the
    // bottom border and the descenders off the named-float row.
    height:             _topMargin +
                        _mainRowHeight +
                        (_namedFloatList.length > 0 ? _barPadding + _namedFloatRowHeight : 0) +
                        _barPadding
    color:              "transparent"
    z:                  10000

    property var    vehicle:            null
    property bool   fieldModeEnabled:   false
    property real   _barPadding:        ScreenTools.defaultFontPixelWidth * 0.5
    property real   _topMargin:         ScreenTools.defaultFontPixelWidth * 0.25
    property real   _popupMargin:       ScreenTools.defaultFontPixelWidth
    property real   _mainRowHeight:     ScreenTools.toolbarHeight * 0.7
    property real   _namedFloatRowHeight: ScreenTools.toolbarHeight * 0.6
    property int    _namedFloatStaleMs: 3000

    readonly property var _appSettings: QGroundControl.settingsManager.appSettings
    readonly property string _namedFloatsSetting: _appSettings && _appSettings.namedFloatsToShow ? _appSettings.namedFloatsToShow.value : ""
    readonly property var _namedFloatValues: (vehicle && vehicle.namedValueFloats) ? vehicle.namedValueFloats.values : ({})
    property int    _namedFloatTick: 0   // bumped by timer to refresh stale state
    property var    _namedFloatList: _buildNamedFloatList(_namedFloatsSetting, _namedFloatValues, _namedFloatTick)

    Timer {
        interval: 1000
        repeat: true
        running: _namedFloatList.length > 0
        onTriggered: _namedFloatTick = (_namedFloatTick + 1) & 0xffff
    }

    function _buildNamedFloatList(raw, values, tick) {
        if (!raw || raw.length === 0) return []
        if (!values) values = {}
        var nowMs = Date.now()
        var entries = raw.split(",")
        var out = []
        for (var i = 0; i < entries.length; i++) {
            var token = entries[i].trim()
            if (token.length === 0) continue
            // Header chip: token starts with '#'
            if (token.charAt(0) === '#') {
                var headerText = token.substring(1).trim()
                if (headerText.length === 0) continue
                out.push({ header: true, label: headerText, name: "", valueText: "", stale: false })
                continue
            }
            var parts = token.split(":")
            var key = parts[0].trim()
            if (key.length === 0) continue
            var hasExplicitLabel = parts.length > 1
            var labelRaw = hasExplicitLabel ? parts.slice(1).join(":").trim() : key
            // Explicit empty label (e.g. "O_C1M:") => value-only pill, no prefix
            var label = (hasExplicitLabel && labelRaw.length === 0) ? "" : labelRaw
            var entry = values[key]
            var hasValue = entry !== undefined && entry !== null && entry.value !== undefined
            var stale = !hasValue || (entry.updatedMs !== undefined && (nowMs - entry.updatedMs) > _namedFloatStaleMs)
            var valueText = hasValue ? Number(entry.value).toFixed(2) : "--"
            out.push({ header: false, name: key, label: label, valueText: valueText, stale: stale })
        }
        return out
    }
    // debug controls removed
    readonly property var _popupParent: root.parent ? root.parent : root

    QGCPalette { id: qgcPal }

    readonly property var _batterySettings: QGroundControl.settingsManager.batteryIndicatorSettings
    readonly property var _rtk: QGroundControl.gpsRtk

    property var _battery: _selectBattery()
    property var _batterySamples: []
    property real _lastBatteryAverage: NaN
    property string _batteryTrend: "-"
    property int _batterySampleSize: 5
    property real _batteryTrendDeadband: 0.5

    readonly property bool _vehicleAvailable: vehicle && !vehicle.isOfflineEditingVehicle

    function _selectBattery() {
        if (!vehicle || !vehicle.batteries || vehicle.batteries.count === 0) {
            return null
        }
        var lowest = vehicle.batteries.get(0)
        var usePercent = true
        for (var i = 0; i < vehicle.batteries.count; i++) {
            var candidate = vehicle.batteries.get(i)
            if (isNaN(candidate.percentRemaining.rawValue)) {
                usePercent = false
                break
            }
        }
        for (var j = 1; j < vehicle.batteries.count; j++) {
            var battery = vehicle.batteries.get(j)
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

    function _updateBatteryTrend(value) {
        if (isNaN(value)) {
            _batterySamples = []
            _lastBatteryAverage = NaN
            _batteryTrend = "-"
            return
        }
        _batterySamples.push(value)
        while (_batterySamples.length > _batterySampleSize) {
            _batterySamples.shift()
        }
        var sum = 0
        for (var i = 0; i < _batterySamples.length; i++) {
            sum += _batterySamples[i]
        }
        var average = sum / _batterySamples.length
        if (isNaN(_lastBatteryAverage)) {
            _lastBatteryAverage = average
            _batteryTrend = "-"
            return
        }
        var delta = average - _lastBatteryAverage
        if (delta > _batteryTrendDeadband) {
            _batteryTrend = "^"
        } else if (delta < -_batteryTrendDeadband) {
            _batteryTrend = "v"
        } else {
            _batteryTrend = "-"
        }
        _lastBatteryAverage = average
    }

    function _severityColor(level) {
        if (level === 2) {
            return qgcPal.colorRed
        } else if (level === 1) {
            return qgcPal.colorOrange
        }
        // Bar background is always dark, so always use a light text color
        return "#e0e0e0"
    }

    function _severityBackground(level) {
        if (level === 2) {
            return Qt.rgba(qgcPal.colorRed.r, qgcPal.colorRed.g, qgcPal.colorRed.b, 0.2)
        } else if (level === 1) {
            return Qt.rgba(qgcPal.colorOrange.r, qgcPal.colorOrange.g, qgcPal.colorOrange.b, 0.2)
        }
        return "transparent"
    }

    function _batterySeverity() {
        if (!_battery) {
            return 0
        }
        var percent = _battery.percentRemaining.rawValue
        if (!isNaN(percent)) {
            if (percent > _batterySettings.threshold1.rawValue) {
                return 0
            } else if (percent > _batterySettings.threshold2.rawValue) {
                return 1
            }
            return 2
        }
        if (_battery.chargeState && _battery.chargeState.rawValue !== MAVLink.MAV_BATTERY_CHARGE_STATE_UNDEFINED) {
            if (_battery.chargeState.rawValue >= MAVLink.MAV_BATTERY_CHARGE_STATE_CRITICAL) {
                return 2
            } else if (_battery.chargeState.rawValue >= MAVLink.MAV_BATTERY_CHARGE_STATE_LOW) {
                return 1
            }
        }
        return 0
    }

    function _batteryText() {
        if (!_battery) {
            return _vehicleAvailable ? qsTr("Battery: --") : qsTr("Battery: —")
        }
        var voltageText = isNaN(_battery.voltage.rawValue) ? "--" : (_battery.voltage.valueString + _battery.voltage.units)
        var percentText = isNaN(_battery.percentRemaining.rawValue) ? "--" : (_battery.percentRemaining.valueString + _battery.percentRemaining.units)
        return qsTr("Battery: %1 %2 %3").arg(voltageText).arg(percentText).arg(_batteryTrend)
    }

    function _gpsSeverity() {
        if (!_gpsAvailable()) {
            return _vehicleAvailable ? (_vehicleArmedOrInFlight() ? 2 : 1) : 0
        }
        if (_gpsLockGood()) {
            if (_gpsPoorHdop()) {
                return 1
            }
            return 0
        }
        return _vehicleArmedOrInFlight() ? 2 : 1
    }

    function _gpsText() {
        if (!_gpsAvailable()) {
            return qsTr("GPS/RTK: —")
        }
        var lockText = vehicle.gps.lock.enumStringValue
        var rtkText = _rtk.connected.value ? qsTr("RTK") : qsTr("No RTK")
        return qsTr("GPS/RTK: %1 / %2").arg(lockText).arg(rtkText)
    }

    function _ratioSeverity(ratio) {
        if (ratio <= 0.5) {
            return 0
        } else if (ratio <= 1.0) {
            return 1
        }
        return 2
    }

    function _ratioAvailable(fact) {
        return fact && fact.rawValue !== undefined && !isNaN(fact.rawValue)
    }

    function _boolAvailable(fact) {
        return fact && fact.rawValue !== undefined
    }

    function _subsystemSeverityRatioOrGood(ratioFact, goodFact, fallbackRatioFact) {
        if (_ratioAvailable(ratioFact)) {
            return _ratioSeverity(ratioFact.rawValue)
        }
        if (_ratioAvailable(fallbackRatioFact)) {
            return _ratioSeverity(fallbackRatioFact.rawValue)
        }
        if (_boolAvailable(goodFact)) {
            return goodFact.rawValue ? 0 : 2
        }
        return -1
    }

    function _subsystemSeverityCompass(est, ekfReport) {
        if (!est && !ekfReport) {
            return -1
        }
        if (est && _ratioAvailable(est.magRatio)) {
            return _ratioSeverity(est.magRatio.rawValue)
        }
        if (ekfReport && _ratioAvailable(ekfReport.compassVariance)) {
            return _ratioSeverity(ekfReport.compassVariance.rawValue)
        }
        if (est && _boolAvailable(est.compassError)) {
            return est.compassError.rawValue ? 2 : 0
        }
        if (est && _boolAvailable(est.goodAttitudeEstimate)) {
            return est.goodAttitudeEstimate.rawValue ? 0 : 2
        }
        return -1
    }

    function _fmt(v) {
        if (v === undefined) return "undef"
        if (v === null) return "null"
        if (typeof v === "number" && isNaN(v)) return "NaN"
        if (typeof v === "object") return "[obj]"
        return "" + v
    }

    function _dumpFact(name, obj) {
        var t = (obj === undefined) ? "undef" : (obj === null ? "null" : typeof obj)
        var s = name + ": type=" + t + " direct=" + _fmt(obj)
        try {
            if (obj && obj.value !== undefined) s += " value=" + _fmt(obj.value)
        } catch(e) { s += " value=<err>" }
        try {
            if (obj && obj.rawValue !== undefined) s += " raw=" + _fmt(obj.rawValue)
        } catch(e) { s += " raw=<err>" }
        return s
    }

    function _logEkfSnapshot() {
        console.log("==== RosorQGC EKF Snapshot ====")
        console.log("vehicle:", _fmt(vehicle))
        if (!vehicle) {
            console.log("EKF: no vehicle")
            return
        }

        var es = vehicle.estimatorStatus
        console.log("vehicle.estimatorStatus:", _fmt(es), "typeof=", typeof es)
        if (es) {
            console.log(_dumpFact("velRatio", es.velRatio))
            console.log(_dumpFact("horizPosRatio", es.horizPosRatio))
            console.log(_dumpFact("vertPosRatio", es.vertPosRatio))
            console.log(_dumpFact("magRatio", es.magRatio))
            console.log(_dumpFact("haglRatio", es.haglRatio))
            console.log(_dumpFact("goodAttitudeEstimate", es.goodAttitudeEstimate))
            console.log(_dumpFact("goodHorizPosAbsEstimate", es.goodHorizPosAbsEstimate))
            console.log(_dumpFact("goodVertPosAbsEstimate", es.goodVertPosAbsEstimate))
            console.log(_dumpFact("goodHorizVelEstimate", es.goodHorizVelEstimate))
            console.log(_dumpFact("goodVertVelEstimate", es.goodVertVelEstimate))
            console.log(_dumpFact("goodVertPosAGLEstimate", es.goodVertPosAGLEstimate))
            console.log(_dumpFact("gpsGlitch", es.gpsGlitch))
            console.log(_dumpFact("accelError", es.accelError))
            console.log(_dumpFact("compassError", es.compassError))
        } else {
            console.log("EKF: estimatorStatus missing")
        }

        var ekfReport = vehicle.ekfStatusReport
        console.log("vehicle.ekfStatusReport:", _fmt(ekfReport), "typeof=", typeof ekfReport)
        if (ekfReport) {
            console.log(_dumpFact("flags", ekfReport.flags))
            console.log(_dumpFact("velVariance", ekfReport.velVariance))
            console.log(_dumpFact("posHorizVariance", ekfReport.posHorizVariance))
            console.log(_dumpFact("posVertVariance", ekfReport.posVertVariance))
            console.log(_dumpFact("compassVariance", ekfReport.compassVariance))
            console.log(_dumpFact("terrainAltVariance", ekfReport.terrainAltVariance))
        } else {
            console.log("EKF: ekfStatusReport missing")
        }

        var estimatorRatioLive = es && (_ratioAvailable(es.velRatio) || _ratioAvailable(es.horizPosRatio) || _ratioAvailable(es.vertPosRatio) || _ratioAvailable(es.magRatio) || _ratioAvailable(es.haglRatio))
        var ekfReportLive = ekfReport && (_ratioAvailable(ekfReport.velVariance) || _ratioAvailable(ekfReport.posHorizVariance) || _ratioAvailable(ekfReport.posVertVariance) || _ratioAvailable(ekfReport.compassVariance) || _ratioAvailable(ekfReport.terrainAltVariance))
        console.log("EKF source:", estimatorRatioLive ? "estimatorStatus" : (ekfReportLive ? "ekfStatusReport" : "none"))
        console.log("==== end EKF Snapshot ====")
    }

    function _ekfStatusReportAvailable() {
        return _vehicleAvailable && vehicle.ekfStatusReport && vehicle.ekfStatusReport.telemetryAvailable
    }

    function _ekfWorstSeverity() {
        if (!_estimatorAvailable() && !_ekfStatusReportAvailable()) {
            return { known: false, severity: -1 }
        }
        var est = vehicle.estimatorStatus
        var ekfReport = vehicle.ekfStatusReport
        var worst = -1
        var known = false

        var velocity = _subsystemSeverityRatioOrGood(est ? est.velRatio : null,
                                                     est ? est.goodHorizVelEstimate : null,
                                                     ekfReport ? ekfReport.velVariance : null)
        var posH = _subsystemSeverityRatioOrGood(est ? est.horizPosRatio : null,
                                                 est ? est.goodHorizPosAbsEstimate : null,
                                                 ekfReport ? ekfReport.posHorizVariance : null)
        var posV = _subsystemSeverityRatioOrGood(est ? est.vertPosRatio : null,
                                                 est ? est.goodVertPosAbsEstimate : null,
                                                 ekfReport ? ekfReport.posVertVariance : null)
        var compass = _subsystemSeverityCompass(est, ekfReport)
        var terrain = _subsystemSeverityRatioOrGood(est ? est.haglRatio : null,
                                                    est ? est.goodVertPosAGLEstimate : null,
                                                    ekfReport ? ekfReport.terrainAltVariance : null)
        var severities = [velocity, posH, posV, compass, terrain]

        for (var i = 0; i < severities.length; i++) {
            var sev = severities[i]
            if (sev >= 0) {
                known = true
                worst = Math.max(worst, sev)
            }
        }
        return { known: known, severity: worst }
    }

    function _ekfSeverity() {
        var result = _ekfWorstSeverity()
        return result.known ? result.severity : 0
    }

    function _ekfTextSafe() {
        var result = _ekfWorstSeverity()
        if (!result.known) {
            return qsTr("EKF: --")
        }
        if (result.severity === 2) {
            return qsTr("EKF: BAD")
        } else if (result.severity === 1) {
            return qsTr("EKF: WARN")
        }
        return qsTr("EKF: OK")
    }

    function _linkSeverity() {
        if (!_vehicleAvailable) {
            return 0
        }
        var rcValid = _rcAvailable()
        var telValid = _telemetryAvailable()
        var rcExpected = vehicle.supportsRadio
        // If the vehicle claims RC support but the link is missing / weak, warn.
        // We do NOT warn on missing telemetry alone — many non-SiK links
        // (USB serial, TCP over WiFi, Herelink) never emit RADIO_STATUS
        // and there's nothing wrong with that.
        if (rcExpected && !rcValid) {
            return _vehicleArmedOrInFlight() ? 2 : 1
        }
        if (rcValid && vehicle.rcRSSI <= 15) {
            return 2
        }
        if (rcValid && vehicle.rcRSSI <= 40) {
            return 1
        }
        return 0
    }

    function _linkText() {
        if (!_vehicleAvailable) {
            return qsTr("Link: —")
        }
        var parts = []
        if (_rcAvailable()) {
            parts.push(qsTr("RC %1%").arg(vehicle.rcRSSI))
        } else if (vehicle.supportsRadio) {
            parts.push(qsTr("RC --"))
        }
        // Only show telemetry chunk if we've actually received a RADIO_STATUS.
        // Otherwise "TLM --" is noise on setups that never send it.
        if (_telemetryAvailable()) {
            parts.push(qsTr("TLM %1 dBm").arg(vehicle.telemetryLRSSI))
        }
        if (parts.length === 0) {
            return qsTr("Link: —")
        }
        return qsTr("Link: %1").arg(parts.join(" / "))
    }

    function _satCount() {
        if (!_vehicleAvailable || !vehicle.gps) return -1
        var n = vehicle.gps.count.rawValue
        return (n === undefined || isNaN(n)) ? -1 : n
    }

    function _satsSeverity() {
        var n = _satCount()
        if (n < 0)  return _vehicleAvailable ? 1 : 0   // no data
        if (n < 6)  return 2                            // too few for RTK/GPS lock
        if (n < 10) return 1                            // marginal
        return 0                                        // good
    }

    function _satsText() {
        var n = _satCount()
        if (!_vehicleAvailable) return qsTr("Sats: —")
        if (n < 0) return qsTr("Sats: --")
        return qsTr("Sats: %1").arg(n)
    }

    function _failsafeSeverity() {
        if (!_vehicleAvailable) {
            return 0
        }
        if (vehicle.messageTypeError) {
            return 2
        }
        if (vehicle.messageTypeWarning) {
            return 1
        }
        return 0
    }

    function _failsafeText() {
        if (!_vehicleAvailable) {
            return qsTr("Failsafe: —")
        }
        if (vehicle.messageTypeError) {
            return qsTr("Failsafe: Active")
        }
        if (vehicle.messageTypeWarning) {
            return qsTr("Failsafe: Warning")
        }
        return qsTr("Failsafe: None")
    }

    Connections {
        target: _battery ? _battery.percentRemaining : null
        ignoreUnknownSignals: true
        function onRawValueChanged() { _updateBatteryTrend(_battery.percentRemaining.rawValue) }
    }

    on_BatteryChanged: {
        if (_battery) {
            _batterySamples = []
            _lastBatteryAverage = NaN
            _updateBatteryTrend(_battery.percentRemaining.rawValue)
        }
    }

    Rectangle {
        id:                 backgroundStrip
        anchors.fill:       parent
        anchors.margins:    _barPadding
        radius:             ScreenTools.defaultBorderRadius
        color:              Qt.rgba(0, 0, 0, 0.45)
    }

    RowLayout {
        id:                     mainStatusRow
        anchors.left:           parent.left
        anchors.right:          parent.right
        anchors.top:            parent.top
        height:                 _mainRowHeight
        anchors.leftMargin:     ScreenTools.defaultFontPixelWidth
        anchors.rightMargin:    ScreenTools.defaultFontPixelWidth
        anchors.topMargin:      _topMargin
        spacing:                ScreenTools.defaultFontPixelWidth

        StatusItem {
            sectionName:   "BAT"
            title:          qsTr("Battery")
            valueText:      _batteryText()
            severity:       _batterySeverity()
            fieldMode:      fieldModeEnabled
            onClicked:      (section, item) => onStatusClicked(section, item)
        }

        StatusItem {
            sectionName:   "GPS"
            title:          qsTr("GPS/RTK")
            valueText:      _gpsText()
            severity:       _gpsSeverity()
            fieldMode:      fieldModeEnabled
            onClicked:      (section, item) => onStatusClicked(section, item)
        }

        StatusItem {
            id:            ekfStatusItem
            sectionName:   "EKF"
            title:          qsTr("EKF")
            valueText:      _ekfTextSafe()
            severity:       _ekfSeverity()
            fieldMode:      fieldModeEnabled
            minOpacity:     0.65
            onClicked:      (section, item) => { _logEkfSnapshot(); onStatusClicked(section, item) }
        }

        StatusItem {
            sectionName:   "SATS"
            title:          qsTr("Sats")
            valueText:      _satsText()
            severity:       _satsSeverity()
            fieldMode:      fieldModeEnabled
            onClicked:      (section, item) => onStatusClicked(section, item)
        }

    }

    RowLayout {
        id:                     namedFloatRow
        visible:                _namedFloatList.length > 0
        anchors.left:           parent.left
        anchors.right:          parent.right
        anchors.top:            mainStatusRow.bottom
        anchors.topMargin:      _barPadding
        height:                 _namedFloatRowHeight
        anchors.leftMargin:     ScreenTools.defaultFontPixelWidth
        anchors.rightMargin:    ScreenTools.defaultFontPixelWidth
        spacing:                ScreenTools.defaultFontPixelWidth

        Repeater {
            model: _namedFloatList
            delegate: Rectangle {
                Layout.fillHeight: true
                Layout.fillWidth: !modelData.header
                Layout.preferredWidth: headerLabel.implicitWidth + (ScreenTools.defaultFontPixelWidth * (modelData.header ? 1 : 2))
                Layout.minimumWidth: modelData.header
                                          ? 0
                                          : (headerLabel.implicitWidth + (ScreenTools.defaultFontPixelWidth * 2))
                radius: ScreenTools.defaultBorderRadius
                color: "transparent"
                border.color: modelData.header ? "transparent" : qgcPal.windowTransparentText
                border.width: modelData.header ? 0 : 1
                opacity: modelData.header
                            ? (fieldModeEnabled ? 0.6 : 1.0)
                            : (modelData.stale ? 0.45 : (fieldModeEnabled ? 0.6 : 1.0))

                QGCLabel {
                    id: headerLabel
                    anchors.fill: parent
                    anchors.leftMargin: ScreenTools.defaultFontPixelWidth * (modelData.header ? 0.25 : 1)
                    anchors.rightMargin: ScreenTools.defaultFontPixelWidth * (modelData.header ? 0.25 : 1)
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: modelData.header ? Text.AlignRight : Text.AlignLeft
                    elide: Text.ElideRight
                    text: modelData.header ? modelData.label
                                           : (modelData.label.length > 0
                                                ? (modelData.label + ": " + modelData.valueText)
                                                : modelData.valueText)
                    color: modelData.header ? "white" : "#e0e0e0"
                    font.bold: modelData.header
                    font.pointSize: ScreenTools.defaultFontPointSize
                }
            }
        }
    }

    function onStatusClicked(sectionKey, clickedItem) {
        showDetails(sectionKey, clickedItem)
    }

    function _positionDetailsPopup(item) {
        var margin = _popupMargin
        var popupParent = detailsPopup.parent ? detailsPopup.parent : root
        var maxX = Math.max(margin, popupParent.width - detailsPopup.width - margin)
        var maxY = Math.max(margin, popupParent.height - detailsPopup.height - margin)
        var x = (popupParent.width - detailsPopup.width) / 2
        var y = (popupParent.height - detailsPopup.height) / 2

        if (item) {
            var point = item.mapToItem(popupParent, 0, 0)
            var itemCenterX = point.x + (item.width / 2)
            var itemTopY = point.y
            var itemBottomY = point.y + item.height
            x = itemCenterX - (detailsPopup.width / 2)
            y = itemTopY - detailsPopup.height - margin
            if (y < margin) {
                y = itemBottomY + margin
            }
        }

        detailsPopup.x = Math.max(margin, Math.min(x, maxX))
        detailsPopup.y = Math.max(margin, Math.min(y, maxY))
    }

    function showDetails(sectionKey, item) {
        console.log("showDetails:", sectionKey, "clickedItem=", item)
        detailsPopup.section = sectionKey
        detailsPopup.open()
        Qt.callLater(function() {
            _positionDetailsPopup(item)
            console.log("popup visible=", detailsPopup.visible, "opened=", detailsPopup.opened)
        })
    }

    Popup {
        id:             detailsPopup
        parent:         _popupParent
        modal:          true
        focus:          true
        closePolicy:    Popup.CloseOnEscape | Popup.CloseOnPressOutside
        width:          Math.min(_popupParent.width * 0.9, ScreenTools.defaultFontPixelWidth * 90)
        height:         Math.max(ScreenTools.defaultFontPixelHeight * 12,
                                 Math.min(contentLayout.implicitHeight + (_popupMargin * 2), _popupParent.height - (_popupMargin * 2)))
        x:              (_popupParent.width - width) / 2
        y:              (_popupParent.height - height) / 2

        property string section: ""
        background: Rectangle {
            anchors.fill: parent
            color: qgcPal.window
            border.color: qgcPal.windowShade
            radius: ScreenTools.defaultBorderRadius
        }

        Flickable {
            anchors.fill: parent
            contentWidth: contentLayout.implicitWidth
            contentHeight: contentLayout.implicitHeight
            clip: true

            ColumnLayout {
                id: contentLayout
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: _popupMargin * 2
                spacing: ScreenTools.defaultFontPixelHeight

                QGCLabel {
                    Layout.fillWidth: true
                    font.pointSize: ScreenTools.largeFontPointSize
                    text: detailsPopup.section === "BAT" ? qsTr("Battery") :
                          detailsPopup.section === "GPS" ? qsTr("GPS / RTK") :
                          detailsPopup.section === "EKF" ? qsTr("EKF") :
                          detailsPopup.section === "LINK" ? qsTr("Link") :
                          detailsPopup.section === "FAILSAFE" ? qsTr("Failsafe") :
                          qsTr("Diagnostics")
                }

                Loader {
                    id: detailsLoader
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredHeight: item ? item.implicitHeight : 0
                    active: detailsPopup.opened
                    visible: detailsPopup.opened
                    sourceComponent: detailsPopup.section === "BAT" ? batteryDetails :
                                     detailsPopup.section === "GPS" ? gpsDetails :
                                     detailsPopup.section === "EKF" ? ekfDetails :
                                     detailsPopup.section === "LINK" ? linkDetails :
                                     detailsPopup.section === "FAILSAFE" ? failsafeDetails :
                                     unknownDetails
                }

                QGCButton {
                    Layout.alignment: Qt.AlignRight
                    text: qsTr("Close")
                    onClicked: detailsPopup.close()
                }
            }
        }
    }

    Component {
        id: batteryDetails

        ColumnLayout {
            spacing: ScreenTools.defaultFontPixelHeight / 2

            LabelledLabel {
                label:      qsTr("Voltage")
                labelText:  _battery && !isNaN(_battery.voltage.rawValue) ? (_battery.voltage.valueString + _battery.voltage.units) : qsTr("--")
            }
            LabelledLabel {
                label:      qsTr("Percent")
                labelText:  _battery && !isNaN(_battery.percentRemaining.rawValue) ? (_battery.percentRemaining.valueString + _battery.percentRemaining.units) : qsTr("--")
            }
            LabelledLabel {
                label:      qsTr("Current")
                labelText:  _battery && !isNaN(_battery.current.rawValue) ? (_battery.current.valueString + _battery.current.units) : qsTr("--")
                visible:    _battery && !isNaN(_battery.current.rawValue)
            }
        }
    }

    Component {
        id: gpsDetails

        ColumnLayout {
            spacing: ScreenTools.defaultFontPixelHeight / 2

            LabelledLabel {
                label:      qsTr("Satellites")
                labelText:  _gpsAvailable() ? vehicle.gps.count.valueString : qsTr("--")
            }
            LabelledLabel {
                label:      qsTr("GPS Lock")
                labelText:  _gpsAvailable() ? vehicle.gps.lock.enumStringValue : qsTr("--")
            }
            LabelledLabel {
                label:      qsTr("HDOP")
                labelText:  _gpsAvailable() ? vehicle.gps.hdop.valueString : qsTr("--")
            }
            LabelledLabel {
                label:      qsTr("RTK")
                labelText:  _rtk.connected.value ? (_rtk.active.value ? qsTr("Survey-in Active") : qsTr("RTK Streaming")) : qsTr("Disconnected")
            }
        }
    }

    Component {
        id: ekfDetails

        EkfStatusPopup {
            vehicle:            root.vehicle
            vehicleAvailable:   _vehicleAvailable
            estimatorAvailable: _estimatorAvailable()
        }
    }

    Component {
        id: linkDetails

        ColumnLayout {
            spacing: ScreenTools.defaultFontPixelHeight / 2

            LabelledLabel {
                label:      qsTr("RC RSSI")
                labelText:  _vehicleAvailable && vehicle.rcRSSI > 0 && vehicle.rcRSSI <= 100 ? qsTr("%1%").arg(vehicle.rcRSSI) : qsTr("--")
            }
            LabelledLabel {
                label:      qsTr("Telemetry L-RSSI")
                labelText:  _vehicleAvailable && vehicle.telemetryLRSSI !== 0 ? qsTr("%1 dBm").arg(vehicle.telemetryLRSSI) : qsTr("--")
            }
            LabelledLabel {
                label:      qsTr("Telemetry R-RSSI")
                labelText:  _vehicleAvailable && vehicle.telemetryRRSSI !== 0 ? qsTr("%1 dBm").arg(vehicle.telemetryRRSSI) : qsTr("--")
            }
            LabelledLabel {
                label:      qsTr("RX Errors")
                labelText:  _vehicleAvailable ? vehicle.telemetryRXErrors : qsTr("--")
            }
        }
    }

    Component {
        id: failsafeDetails

        Item {
            property var _activeVehicle: vehicle

            ColumnLayout {
                anchors.fill: parent
                spacing: ScreenTools.defaultFontPixelHeight / 2

                LabelledLabel {
                    label:      qsTr("State")
                    labelText:  _failsafeText()
                }
                LabelledLabel {
                    label:      qsTr("Message Count")
                    labelText:  _vehicleAvailable ? vehicle.messageCount : qsTr("--")
                }

                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: _vehicleAvailable ? vehicleMessageListComponent : undefined
                }
            }
        }
    }

    Component {
        id: unknownDetails

        QGCLabel {
            text: qsTr("No diagnostics available")
        }
    }

    Component {
        id: vehicleMessageListComponent

        Item {
            property var _activeVehicle: vehicle

            VehicleMessageList {
                anchors.fill: parent
            }
        }
    }

    function _gpsAvailable() {
        return _vehicleAvailable && vehicle.gps && vehicle.gps.telemetryAvailable
    }

    function _gpsLockGood() {
        return _gpsAvailable() && vehicle.gps.lock.rawValue >= 3
    }

    function _gpsPoorHdop() {
        return _gpsAvailable() && !isNaN(vehicle.gps.hdop.rawValue) && vehicle.gps.hdop.rawValue > 2.0
    }

    function _vehicleArmedOrInFlight() {
        return _vehicleAvailable && (vehicle.armed || vehicle.flying || vehicle.landing)
    }

    function _estimatorAvailable() {
        return _vehicleAvailable && vehicle.estimatorStatus && vehicle.estimatorStatus.telemetryAvailable
    }

    function _estimatorFactValue(fact) {
        return fact && fact.rawValue !== undefined ? fact.rawValue : undefined
    }

    function _estimatorIsTrue(value) {
        return value === true || value === 1
    }

    function _estimatorIsFalse(value) {
        return value === false || value === 0
    }

    function _estimatorHasData() {
        if (!_vehicleAvailable || !vehicle.estimatorStatus) {
            return false
        }
        var est = vehicle.estimatorStatus
        return est.goodAttitudeEstimate ||
               est.goodHorizPosAbsEstimate ||
               est.goodVertPosAbsEstimate ||
               est.goodHorizVelEstimate ||
               est.goodVertVelEstimate ||
               est.gpsGlitch ||
               est.accelError ||
               est.velRatio ||
               est.horizPosRatio ||
               est.vertPosRatio ||
               est.magRatio ||
               est.haglRatio
    }

    function _rcAvailable() {
        return _vehicleAvailable && vehicle.supportsRadio && vehicle.rcRSSI > 0 && vehicle.rcRSSI <= 100
    }

    function _telemetryAvailable() {
        return _vehicleAvailable && vehicle.telemetryLRSSI !== 0
    }

    component StatusItem: Rectangle {
        id: statusItem
        property string title: ""
        property string valueText: ""
        property int severity: 0
        property bool fieldMode: false
        property real minOpacity: 0.0
        property string sectionName: ""
        signal clicked(string section, var item)

        radius: ScreenTools.defaultBorderRadius
        color: _severityBackground(severity)
        border.color: _severityColor(severity)
        border.width: severity > 0 ? 1 : 0
        opacity: Math.max(fieldMode && severity === 0 ? 0.6 : 1.0, minOpacity)

        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 10

        QGCLabel {
            anchors.fill: parent
            anchors.margins: ScreenTools.defaultFontPixelWidth
            verticalAlignment: Text.AlignVCenter
            text: valueText
            color: severity > 0 ? qgcPal.window : _severityColor(severity)
            elide: Text.ElideRight
            font.pointSize: fieldMode && severity === 0 ? ScreenTools.smallFontPointSize + 1 : ScreenTools.defaultFontPointSize + 1
        }

        MouseArea {
            anchors.fill: parent
            enabled: true
            visible: true
            acceptedButtons: Qt.LeftButton
            hoverEnabled: true
            preventStealing: true
            propagateComposedEvents: false
            z: 9999
            onClicked: {
                console.log("CriticalStatusBar click:", statusItem.sectionName)
                statusItem.clicked(statusItem.sectionName, statusItem)
            }
        }
    }
}
