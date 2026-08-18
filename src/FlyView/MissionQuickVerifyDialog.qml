import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtCharts

import QGroundControl
import QGroundControl.Controls

QGCPopupDialog {
    id: root

    title:      qsTr("Mission Quick Verify")
    buttons:    Dialog.Close
    modal:      true

    property var missionController: null
    property var _unitsConversion:  QGroundControl.unitsConversion
    property bool _clearanceHasData: false
    property real _clearanceMin: 0
    property real _clearanceMax: 0

    readonly property real _sectionGap: ScreenTools.defaultFontPixelHeight * 0.75
    readonly property real _chartHeight: ScreenTools.defaultFontPixelHeight * 12

    onOpened: _scheduleClearanceUpdate()

    function _scheduleClearanceUpdate() {
        if (_clearanceUpdateTimer.running) {
            _clearanceUpdateTimer.restart()
        } else {
            _clearanceUpdateTimer.start()
        }
    }

    function _appendClearancePoint(series, xMeters, clearanceMeters) {
        series.append(_unitsConversion.metersToAppSettingsHorizontalDistanceUnits(xMeters),
                      _unitsConversion.metersToAppSettingsVerticalDistanceUnits(clearanceMeters))
    }

    function _buildClearanceSeries() {
        clearanceSeries.clear()
        _clearanceHasData = false
        _clearanceMin = 0
        _clearanceMax = 0

        if (!missionController || !missionController.simpleFlightPathSegments) {
            _applyClearanceAxisDefaults()
            return
        }

        var segments = missionController.simpleFlightPathSegments
        var totalDistance = 0
        for (var i = 0; i < segments.count; i++) {
            var segment = segments.get(i)
            if (!segment || !segment.amslTerrainHeights || segment.amslTerrainHeights.length === 0) {
                totalDistance += segment ? segment.totalDistance : 0
                continue
            }

            var segDistance = 0
            var segTotal = segment.totalDistance
            var slope = segTotal > 0 ? (segment.coord2AMSLAlt - segment.coord1AMSLAlt) / segTotal : 0
            var intercept = segment.coord1AMSLAlt
            for (var j = 0; j < segment.amslTerrainHeights.length; j++) {
                var terrainAlt = segment.amslTerrainHeights[j]
                if (!isNaN(terrainAlt)) {
                    var flightAlt = intercept + (slope * segDistance)
                    var clearance = flightAlt - terrainAlt
                    _appendClearancePoint(clearanceSeries, totalDistance + segDistance, clearance)
                    if (!_clearanceHasData) {
                        _clearanceMin = clearance
                        _clearanceMax = clearance
                        _clearanceHasData = true
                    } else {
                        _clearanceMin = Math.min(_clearanceMin, clearance)
                        _clearanceMax = Math.max(_clearanceMax, clearance)
                    }
                }

                if (j === segment.amslTerrainHeights.length - 2) {
                    segDistance += segment.finalDistanceBetween
                } else {
                    segDistance += segment.distanceBetween
                }
            }

            totalDistance += segTotal
        }

        if (_clearanceHasData) {
            _applyClearanceAxisRange(totalDistance, _clearanceMin, _clearanceMax)
        } else {
            _applyClearanceAxisDefaults()
        }
    }

    function _applyClearanceAxisDefaults() {
        axisX.min = 0
        axisX.max = 1
        axisY.min = 0
        axisY.max = 1
    }

    function _applyClearanceAxisRange(totalDistanceMeters, minClearanceMeters, maxClearanceMeters) {
        var xMax = Math.max(1, totalDistanceMeters)
        axisX.min = 0
        axisX.max = _unitsConversion.metersToAppSettingsHorizontalDistanceUnits(xMax)

        var minVal = minClearanceMeters
        var maxVal = maxClearanceMeters
        if (minVal === maxVal) {
            minVal -= 1
            maxVal += 1
        }
        axisY.min = _unitsConversion.metersToAppSettingsVerticalDistanceUnits(minVal)
        axisY.max = _unitsConversion.metersToAppSettingsVerticalDistanceUnits(maxVal)
    }

    Connections {
        target: missionController
        function onVisualItemsChanged() { _scheduleClearanceUpdate() }
        function onMissionTotalDistanceChanged() { _scheduleClearanceUpdate() }
    }

    Connections {
        target: missionController ? missionController.simpleFlightPathSegments : null
        function onCountChanged() { _scheduleClearanceUpdate() }
    }

    Timer {
        id: _clearanceUpdateTimer
        interval: 250
        repeat: false
        onTriggered: _buildClearanceSeries()
    }

    ColumnLayout {
        spacing: _sectionGap

        QGCLabel {
            Layout.fillWidth: true
            font.pointSize: ScreenTools.largeFontPointSize
            text: qsTr("Terrain Profile (AMSL)")
        }

        TerrainStatus {
            Layout.fillWidth: true
            Layout.preferredHeight: _chartHeight
            missionController: root.missionController
        }

        QGCLabel {
            Layout.fillWidth: true
            font.pointSize: ScreenTools.largeFontPointSize
            text: qsTr("Clearance (AGL)")
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: _chartHeight

            ChartView {
                id:                 clearanceChart
                anchors.fill:       parent
                margins.top:        0
                margins.right:      0
                margins.bottom:     0
                margins.left:       0
                backgroundColor:    "transparent"
                legend.visible:     false
                antialiasing:       true

                ValueAxis {
                    id:                 axisX
                    min:                0
                    max:                1
                    lineVisible:        true
                    labelsFont.family:  ScreenTools.fixedFontFamily
                    labelsFont.pointSize: ScreenTools.smallFontPointSize
                    labelsColor:        QGroundControl.globalPalette.text
                    tickCount:          5
                    gridLineColor:      Qt.rgba(1, 1, 1, 0.2)
                }

                ValueAxis {
                    id:                 axisY
                    min:                0
                    max:                1
                    lineVisible:        true
                    labelsFont.family:  ScreenTools.fixedFontFamily
                    labelsFont.pointSize: ScreenTools.smallFontPointSize
                    labelsColor:        QGroundControl.globalPalette.text
                    tickCount:          4
                    gridLineColor:      Qt.rgba(1, 1, 1, 0.2)
                }

                LineSeries {
                    id:     clearanceSeries
                    axisX:  axisX
                    axisY:  axisY
                }
            }

            QGCLabel {
                anchors.centerIn: parent
                text: qsTr("Terrain data unavailable")
                visible: !_clearanceHasData
            }
        }
    }
}
