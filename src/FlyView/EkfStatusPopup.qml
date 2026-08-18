import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Item {
    id: root

    property var vehicle: QGroundControl.multiVehicleManager.activeVehicle
    property bool vehicleAvailable: false
    property bool estimatorAvailable: false
    property bool debugVisible: false
    property var est: vehicle ? vehicle.estimatorStatus : null
    property var ekf: vehicle ? vehicle.ekfStatusReport : null
    // debug controls removed
    property var _barsItem: null
    property var _flagsItem: null

    implicitWidth: ScreenTools.defaultFontPixelWidth * 60
    implicitHeight: ScreenTools.defaultFontPixelHeight * 25
    width: parent ? parent.width : implicitWidth
    height: parent ? parent.height : implicitHeight
    Layout.fillWidth: true
    Layout.fillHeight: true
    opacity: 1.0

    readonly property bool _hasVehicle: vehicle !== null
    readonly property bool _hasEstimator: est && est.telemetryAvailable
    readonly property bool _hasEkfReport: ekf && ekf.telemetryAvailable
    readonly property bool _hasEstimatorData: est && (_isFiniteNumber(est.velRatio ? est.velRatio.rawValue : undefined) ||
                                                     _isFiniteNumber(est.horizPosRatio ? est.horizPosRatio.rawValue : undefined) ||
                                                     _isFiniteNumber(est.vertPosRatio ? est.vertPosRatio.rawValue : undefined) ||
                                                     _isFiniteNumber(est.magRatio ? est.magRatio.rawValue : undefined) ||
                                                     _isFiniteNumber(est.haglRatio ? est.haglRatio.rawValue : undefined))
    readonly property bool _hasEkfReportData: ekf && (_isFiniteNumber(ekf.velVariance ? ekf.velVariance.rawValue : undefined) ||
                                                     _isFiniteNumber(ekf.posHorizVariance ? ekf.posHorizVariance.rawValue : undefined) ||
                                                     _isFiniteNumber(ekf.posVertVariance ? ekf.posVertVariance.rawValue : undefined) ||
                                                     _isFiniteNumber(ekf.compassVariance ? ekf.compassVariance.rawValue : undefined) ||
                                                     _isFiniteNumber(ekf.terrainAltVariance ? ekf.terrainAltVariance.rawValue : undefined))
    readonly property bool _hasEkfData: _hasEstimatorData || _hasEkfReportData || _hasEstimator || _hasEkfReport
    readonly property bool _narrowLayout: width < ScreenTools.defaultFontPixelWidth * 60
    readonly property real _barHeight: ScreenTools.defaultFontPixelHeight * 8
    readonly property real _barWidth: ScreenTools.defaultFontPixelWidth * 3.2
    readonly property real _barRadius: ScreenTools.defaultBorderRadius
    readonly property real _gap: ScreenTools.defaultFontPixelHeight * 0.5

    QGCPalette { id: qgcPal }

    // debug logging removed

    function _isFiniteNumber(value) {
        return value !== undefined && value !== null && !isNaN(value) && isFinite(value)
    }

    function _ratioValue(fact) {
        if (!fact || !_isFiniteNumber(fact.rawValue)) {
            return NaN
        }
        return fact.rawValue
    }

    function _boolValue(fact) {
        if (!fact || fact.rawValue === undefined) {
            return undefined
        }
        return fact.rawValue
    }

    function _fillFromRatio(ratio) {
        var clamped = Math.max(0, Math.min(2, ratio))
        if (clamped <= 0.5) {
            return 1
        } else if (clamped <= 1.0) {
            return 1.5 - clamped
        }
        return Math.max(0, 1.0 - (0.5 * clamped))
    }

    function _severityFromRatio(ratio) {
        if (ratio <= 0.5) {
            return 0
        } else if (ratio <= 1.0) {
            return 1
        }
        return 2
    }

    function _severityColor(level) {
        if (level === 2) {
            return qgcPal.colorRed
        } else if (level === 1) {
            return qgcPal.colorOrange
        }
        return qgcPal.colorGreen
    }

    function _flagColor(value, isError) {
        if (value === undefined) {
            return qgcPal.windowShade
        }
        if (isError) {
            return value ? qgcPal.colorRed : qgcPal.colorGreen
        }
        return value ? qgcPal.colorGreen : qgcPal.colorRed
    }

    function _subsystemSeverity(label) {
        if (!est && !ekf) {
            return -1
        }
        var ratioFact = null
        var goodFact = null
        var errorFact = null

        if (label === "Velocity") {
            ratioFact = est ? est.velRatio : null
            goodFact = est ? est.goodHorizVelEstimate : null
            if (isNaN(_ratioValue(ratioFact)) && ekf) {
                ratioFact = ekf.velVariance
            }
        } else if (label === "PosH") {
            ratioFact = est ? est.horizPosRatio : null
            goodFact = est ? est.goodHorizPosAbsEstimate : null
            if (isNaN(_ratioValue(ratioFact)) && ekf) {
                ratioFact = ekf.posHorizVariance
            }
        } else if (label === "PosV") {
            ratioFact = est ? est.vertPosRatio : null
            goodFact = est ? est.goodVertPosAbsEstimate : null
            if (isNaN(_ratioValue(ratioFact)) && ekf) {
                ratioFact = ekf.posVertVariance
            }
        } else if (label === "Compass") {
            ratioFact = est ? est.magRatio : null
            errorFact = est ? est.compassError : null
            if (isNaN(_ratioValue(ratioFact)) && ekf) {
                ratioFact = ekf.compassVariance
            }
            if (ratioFact && !isNaN(_ratioValue(ratioFact))) {
                errorFact = null
                goodFact = null
            } else if (errorFact && _boolValue(errorFact) !== undefined) {
                ratioFact = null
                goodFact = null
            } else {
                ratioFact = null
                errorFact = null
                goodFact = est ? est.goodAttitudeEstimate : null
            }
        } else if (label === "Terrain") {
            ratioFact = est ? est.haglRatio : null
            goodFact = est ? est.goodVertPosAGLEstimate : null
            if (isNaN(_ratioValue(ratioFact)) && ekf) {
                ratioFact = ekf.terrainAltVariance
            }
        }

        var ratio = _ratioValue(ratioFact)
        if (!isNaN(ratio)) {
            return _severityFromRatio(ratio)
        }
        var error = _boolValue(errorFact)
        if (error !== undefined) {
            return error ? 2 : 0
        }
        var good = _boolValue(goodFact)
        if (good !== undefined) {
            return good ? 0 : 2
        }
        return -1
    }

    function _ekfSummaryText() {
        var labels = [ "Velocity", "PosH", "PosV", "Compass", "Terrain" ]
        var worstSeverity = -1
        var worstLabel = ""
        for (var i = 0; i < labels.length; i++) {
            var severity = _subsystemSeverity(labels[i])
            if (severity < 0) {
                continue
            }
            if (severity > worstSeverity) {
                worstSeverity = severity
                worstLabel = labels[i]
            }
        }
        if (worstSeverity < 0) {
            return qsTr("EKF: --")
        }
        if (worstSeverity === 0) {
            return qsTr("EKF: OK")
        } else if (worstSeverity === 1) {
            return qsTr("EKF: WARN (%1)").arg(worstLabel)
        }
        return qsTr("EKF: BAD (%1)").arg(worstLabel)
    }

    function _computeSubsystem(label) {
        var ratioFact = null
        var goodFact = null
        var errorFact = null
        var source = "none"

        if (label === "Velocity") {
            ratioFact = est ? est.velRatio : null
            goodFact = est ? est.goodHorizVelEstimate : null
            if (!_isFiniteNumber(_ratioValue(ratioFact)) && ekf) {
                ratioFact = ekf.velVariance
            }
        } else if (label === "PosH") {
            ratioFact = est ? est.horizPosRatio : null
            goodFact = est ? est.goodHorizPosAbsEstimate : null
            if (!_isFiniteNumber(_ratioValue(ratioFact)) && ekf) {
                ratioFact = ekf.posHorizVariance
            }
        } else if (label === "PosV") {
            ratioFact = est ? est.vertPosRatio : null
            goodFact = est ? est.goodVertPosAbsEstimate : null
            if (!_isFiniteNumber(_ratioValue(ratioFact)) && ekf) {
                ratioFact = ekf.posVertVariance
            }
        } else if (label === "Compass") {
            ratioFact = est ? est.magRatio : null
            errorFact = est ? est.compassError : null
            if (!_isFiniteNumber(_ratioValue(ratioFact)) && ekf) {
                ratioFact = ekf.compassVariance
            }
        } else if (label === "Terrain") {
            ratioFact = est ? est.haglRatio : null
            goodFact = est ? est.goodVertPosAGLEstimate : null
            if (!_isFiniteNumber(_ratioValue(ratioFact)) && ekf) {
                ratioFact = ekf.terrainAltVariance
            }
        }

        var ratio = _ratioValue(ratioFact)
        if (_isFiniteNumber(ratio)) {
            source = (est && ratioFact === (label === "Velocity" ? est.velRatio :
                                            label === "PosH" ? est.horizPosRatio :
                                            label === "PosV" ? est.vertPosRatio :
                                            label === "Compass" ? est.magRatio :
                                            est.haglRatio)) ? "est" : "ekf"
            return { fill: _fillFromRatio(ratio), severity: _severityFromRatio(ratio), source: source }
        }

        var error = _boolValue(errorFact)
        if (error !== undefined) {
            return { fill: error ? 0 : 1, severity: error ? 2 : 0, source: "flag" }
        }

        var good = _boolValue(goodFact)
        if (good !== undefined) {
            return { fill: good ? 1 : 0, severity: good ? 0 : 2, source: "flag" }
        }

        return { fill: NaN, severity: -1, source: "none" }
    }

    // debug helper removed

    function _flagsModel() {
        var entries = []
        if (!est) {
            return entries
        }
        function add(name, fact) {
            if (fact) {
                entries.push({ label: name, value: _boolValue(fact) })
            }
        }
        add("goodAttitudeEstimate", est.goodAttitudeEstimate)
        add("goodHorizPosAbsEstimate", est.goodHorizPosAbsEstimate)
        add("goodVertPosAbsEstimate", est.goodVertPosAbsEstimate)
        add("goodHorizVelEstimate", est.goodHorizVelEstimate)
        add("goodVertVelEstimate", est.goodVertVelEstimate)
        add("gpsGlitch", est.gpsGlitch)
        add("accelError", est.accelError)
        return entries
    }

    function _fmt(value) {
        if (value === undefined) return "undef"
        if (value === null) return "null"
        if (typeof value === "number" && isNaN(value)) return "NaN"
        if (typeof value === "object") return "[obj]"
        return "" + value
    }

    function _factDump(fact) {
        if (!fact) return "undef"
        var hasValue = (fact.value !== undefined)
        var hasRaw = (fact.rawValue !== undefined)
        var text = _fmt(fact)
        if (hasValue) text += " value=" + _fmt(fact.value)
        if (hasRaw) text += " raw=" + _fmt(fact.rawValue)
        text += " typeof=" + (typeof fact)
        return text
    }

    function _debugDump() {
        var estDump = est
        var lines = []
        lines.push("vehicle: " + _fmt(vehicle !== null))
        lines.push("estimatorStatus: " + _fmt(estDump !== null) + " typeof=" + (typeof estDump))
        function addField(name) {
            var obj = estDump ? estDump[name] : undefined
            lines.push(name + ": " + _factDump(obj))
        }
        addField("velRatio")
        addField("horizPosRatio")
        addField("vertPosRatio")
        addField("magRatio")
        addField("haglRatio")
        addField("goodAttitudeEstimate")
        addField("goodHorizPosAbsEstimate")
        addField("goodVertPosAbsEstimate")
        addField("goodHorizVelEstimate")
        addField("goodVertVelEstimate")
        addField("goodVertPosAGLEstimate")
        lines.push("ekfStatusReport: " + _fmt(ekf !== null) + " typeof=" + (typeof ekf))
        function addEkf(name) {
            var obj = ekf ? ekf[name] : undefined
            lines.push(name + ": " + _factDump(obj))
        }
        addEkf("flags")
        addEkf("velVariance")
        addEkf("posHorizVariance")
        addEkf("posVertVariance")
        addEkf("compassVariance")
        addEkf("terrainAltVariance")
        return lines.join("\n")
    }

    Component {
        id: ekfBarComponent

        ColumnLayout {
            property string label: ""
            property var ratioFact: null
            property var goodFact: null
            property var errorFact: null

            readonly property real _ratio: _ratioValue(ratioFact)
            readonly property var _good: _boolValue(goodFact)
            readonly property var _error: _boolValue(errorFact)
            readonly property bool _hasRatio: !isNaN(_ratio)
            readonly property bool _unknown: !_hasRatio && _error === undefined && _good === undefined
            readonly property real _fill: _hasRatio ? _fillFromRatio(_ratio) :
                                         (_error !== undefined ? (_error ? 0 : 1) :
                                         (_unknown ? NaN : (_good ? 1 : 0)))
            readonly property int _severity: _hasRatio ? _severityFromRatio(_ratio) :
                                          (_error !== undefined ? (_error ? 2 : 0) :
                                          (_unknown ? -1 : (_good ? 0 : 2)))

            spacing: ScreenTools.defaultFontPixelHeight * 0.3
            Layout.alignment: Qt.AlignHCenter

            Rectangle {
                width: _barWidth
                height: _barHeight
                radius: _barRadius
                color: Qt.rgba(0, 0, 0, 0.35)
                border.color: qgcPal.windowShade

                Rectangle {
                    width: parent.width
                    height: _unknown ? 0 : parent.height * Math.max(0, Math.min(1, _fill))
                    anchors.bottom: parent.bottom
                    radius: _barRadius
                    color: _unknown ? qgcPal.windowShade : _severityColor(_severity)
                }

                QGCLabel {
                    anchors.centerIn: parent
                    text: _unknown ? qsTr("--") : ""
                    color: qgcPal.text
                    visible: _unknown
                }
            }

            QGCLabel {
                text: label
                horizontalAlignment: Text.AlignHCenter
                color: qgcPal.text
            }
        }
    }

    Flickable {
        anchors.fill: parent
        clip: true
        contentWidth: contentLayout.implicitWidth
        contentHeight: contentLayout.implicitHeight

        ColumnLayout {
            id: contentLayout
            width: parent.width
            spacing: _gap

            QGCLabel {
                Layout.fillWidth: true
                text: qsTr("Unavailable (no vehicle)")
                visible: !_hasVehicle
                color: qgcPal.text
            }

            QGCLabel {
                Layout.fillWidth: true
                text: qsTr("Estimator data unavailable")
                visible: _hasVehicle && !_hasEkfData
                color: qgcPal.text
            }

            Loader {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: _hasVehicle && _hasEkfData
                sourceComponent: _narrowLayout ? narrowLayout : wideLayout
            }
        }
    }

    Component {
        id: barRowComponent

        RowLayout {
            spacing: ScreenTools.defaultFontPixelWidth

            Loader {
                sourceComponent: ekfBarComponent
                onLoaded: {
                    item.label = qsTr("Velocity")
                    var ratioFact = est ? est.velRatio : null
                    if (isNaN(_ratioValue(ratioFact)) && ekf) {
                        ratioFact = ekf.velVariance
                    }
                    item.ratioFact = ratioFact
                    item.goodFact = est ? est.goodHorizVelEstimate : null
                }
            }

            Loader {
                sourceComponent: ekfBarComponent
                onLoaded: {
                    item.label = qsTr("Position H")
                    var ratioFact = est ? est.horizPosRatio : null
                    if (isNaN(_ratioValue(ratioFact)) && ekf) {
                        ratioFact = ekf.posHorizVariance
                    }
                    item.ratioFact = ratioFact
                    item.goodFact = est ? est.goodHorizPosAbsEstimate : null
                }
            }

            Loader {
                sourceComponent: ekfBarComponent
                onLoaded: {
                    item.label = qsTr("Position V")
                    var ratioFact = est ? est.vertPosRatio : null
                    if (isNaN(_ratioValue(ratioFact)) && ekf) {
                        ratioFact = ekf.posVertVariance
                    }
                    item.ratioFact = ratioFact
                    item.goodFact = est ? est.goodVertPosAbsEstimate : null
                }
            }

            Loader {
                sourceComponent: ekfBarComponent
                onLoaded: {
                    item.label = qsTr("Compass")
                    var ratioFact = est ? est.magRatio : null
                    if (isNaN(_ratioValue(ratioFact)) && ekf) {
                        ratioFact = ekf.compassVariance
                    }
                    var ratio = _ratioValue(ratioFact)
                    var compassError = _boolValue(est ? est.compassError : null)
                    if (!isNaN(ratio)) {
                        item.ratioFact = ratioFact
                        item.goodFact = null
                        item.errorFact = null
                    } else if (compassError !== undefined) {
                        item.ratioFact = null
                        item.goodFact = null
                        item.errorFact = est ? est.compassError : null
                    } else {
                        item.label = qsTr("Compass (est)")
                        item.ratioFact = null
                        item.goodFact = est ? est.goodAttitudeEstimate : null
                        item.errorFact = null
                    }
                }
            }

            Loader {
                sourceComponent: ekfBarComponent
                onLoaded: {
                    item.label = qsTr("Terrain")
                    var ratioFact = est ? est.haglRatio : null
                    if (isNaN(_ratioValue(ratioFact)) && ekf) {
                        ratioFact = ekf.terrainAltVariance
                    }
                    item.ratioFact = ratioFact
                    item.goodFact = est ? est.goodVertPosAGLEstimate : null
                }
            }
        }
    }

    Component {
        id: flagsColumnComponent

        ColumnLayout {
            spacing: ScreenTools.defaultFontPixelHeight * 0.3

            QGCLabel {
                text: qsTr("Core")
                color: qgcPal.text
            }

            Repeater {
                model: _flagsModel().filter(function(entry) { return entry.label.indexOf("good") === 0 })

                RowLayout {
                    spacing: ScreenTools.defaultFontPixelWidth * 0.5

                    QGCLabel {
                        text: modelData.label
                        color: qgcPal.text
                    }

                    Rectangle {
                        radius: ScreenTools.defaultBorderRadius
                        color: _flagColor(modelData.value, false)
                        height: ScreenTools.defaultFontPixelHeight * 1.2
                        width: ScreenTools.defaultFontPixelWidth * 5

                        QGCLabel {
                            anchors.centerIn: parent
                            text: modelData.value === undefined ? qsTr("--") : (modelData.value ? qsTr("On") : qsTr("Off"))
                            color: qgcPal.text
                        }
                    }
                }
            }

            QGCLabel {
                text: qsTr("Errors")
                color: qgcPal.text
            }

            Repeater {
                model: _flagsModel().filter(function(entry) { return entry.label.indexOf("good") !== 0 })

                RowLayout {
                    spacing: ScreenTools.defaultFontPixelWidth * 0.5

                    QGCLabel {
                        text: modelData.label
                        color: qgcPal.text
                    }

                    Rectangle {
                        radius: ScreenTools.defaultBorderRadius
                        color: _flagColor(modelData.value, true)
                        height: ScreenTools.defaultFontPixelHeight * 1.2
                        width: ScreenTools.defaultFontPixelWidth * 5

                        QGCLabel {
                            anchors.centerIn: parent
                            text: modelData.value === undefined ? qsTr("--") : (modelData.value ? qsTr("On") : qsTr("Off"))
                            color: qgcPal.text
                        }
                    }
                }
            }
        }
    }

    Component {
        id: wideLayout

        RowLayout {
            spacing: ScreenTools.defaultFontPixelWidth * 2

            ColumnLayout {
                Layout.alignment: Qt.AlignTop
                QGCLabel {
                    Layout.fillWidth: true
                    text: _ekfSummaryText()
                    color: qgcPal.text
                }
                Loader {
                    id: barsLoaderWide
                    sourceComponent: barRowComponent
                    onLoaded: root._barsItem = item
                }

                QGCButton {
                    text: debugVisible ? qsTr("Hide debug") : qsTr("Debug")
                    onClicked: debugVisible = !debugVisible
                }

                ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 8
                    visible: debugVisible

                    Text {
                        width: parent.width
                        text: _debugDump()
                        color: qgcPal.text
                        wrapMode: Text.WrapAnywhere
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                Loader {
                    id: flagsLoaderWide
                    sourceComponent: flagsColumnComponent
                    onLoaded: root._flagsItem = item
                }
            }
        }
    }

    Component {
        id: narrowLayout

        ColumnLayout {
            spacing: _gap

            QGCLabel {
                Layout.fillWidth: true
                text: _ekfSummaryText()
                color: qgcPal.text
            }
            Loader {
                id: barsLoaderNarrow
                sourceComponent: barRowComponent
                onLoaded: root._barsItem = item
            }
            Loader {
                id: flagsLoaderNarrow
                sourceComponent: flagsColumnComponent
                onLoaded: root._flagsItem = item
            }

            QGCButton {
                text: debugVisible ? qsTr("Hide debug") : qsTr("Debug")
                onClicked: debugVisible = !debugVisible
            }

            ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 8
                visible: debugVisible

                Text {
                    width: parent.width
                    text: _debugDump()
                    color: qgcPal.text
                    wrapMode: Text.WrapAnywhere
                }
            }
        }
    }
}
