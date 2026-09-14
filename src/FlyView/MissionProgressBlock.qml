import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// The mission block at the foot of the artboard's instrument column: which
/// waypoint the aircraft is on, how far through the plan it is, and what is
/// left to fly.
///
/// Everything degrades to an em dash rather than a zero. "WP 0 of 0" over an
/// empty bar reads like a mission that is loaded and stalled; a dash reads like
/// no mission, which is the truth.
Rectangle {
    id: root

    property var   missionController: null
    property color accentColor:       "#3A9BDC"

    color: qgcPal.window

    QGCPalette { id: qgcPal }

    readonly property int  _count:   missionController ? missionController.missionItemCount    : 0
    readonly property int  _current: missionController ? missionController.currentMissionIndex : 0
    readonly property bool _haveMission: _count > 0

    readonly property real _fraction: _haveMission
                                        ? Math.max(0, Math.min(1, _current / _count))
                                        : 0

    readonly property real _distanceM: missionController ? missionController.missionTotalDistance : NaN
    readonly property real _timeS:     missionController ? missionController.missionTime          : NaN

    readonly property string _timeText: {
        if (isNaN(_timeS) || !isFinite(_timeS) || _timeS <= 0) {
            return "—"
        }
        var total = Math.round(_timeS)
        var mins  = Math.floor(total / 60)
        var secs  = total % 60
        return qsTr("%1:%2 left").arg(mins).arg(secs < 10 ? "0" + secs : secs)
    }

    readonly property string _distanceText: {
        if (isNaN(_distanceM) || !isFinite(_distanceM) || _distanceM <= 0) {
            return "—"
        }
        return _distanceM >= 1000 ? qsTr("%1 km").arg((_distanceM / 1000).toFixed(1))
                                  : qsTr("%1 m").arg(_distanceM.toFixed(0))
    }

    ColumnLayout {
        anchors.fill:           parent
        anchors.margins:        ScreenTools.defaultFontPixelWidth * 0.8
        spacing:                ScreenTools.defaultFontPixelHeight * 0.25

        QGCLabel {
            Layout.fillWidth:   true
            text:               qsTr("MISSION")
            font.pointSize:     ScreenTools.smallFontPointSize
            color:              qgcPal.windowTransparentText
        }

        RowLayout {
            Layout.fillWidth:   true
            spacing:            ScreenTools.defaultFontPixelWidth * 0.5

            QGCLabel {
                Layout.alignment:   Qt.AlignBaseline
                text:               root._haveMission ? qsTr("WP %1").arg(root._current) : qsTr("WP —")
                font.pointSize:     ScreenTools.defaultFontPointSize * 1.15
                font.bold:          true
                color:              qgcPal.text
            }

            QGCLabel {
                Layout.alignment:   Qt.AlignBaseline
                text:               root._haveMission ? qsTr("of %1").arg(root._count) : ""
                font.pointSize:     ScreenTools.smallFontPointSize
                color:              qgcPal.windowTransparentText
            }

            Item { Layout.fillWidth: true }
        }

        // Track and fill, 8px in the artboard.
        Rectangle {
            Layout.fillWidth:       true
            Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 0.3
            color:                  qgcPal.windowShade

            Rectangle {
                anchors.left:   parent.left
                anchors.top:    parent.top
                anchors.bottom: parent.bottom
                width:          parent.width * root._fraction
                color:          root.accentColor
                visible:        root._haveMission
            }
        }

        RowLayout {
            Layout.fillWidth:   true
            spacing:            0

            QGCLabel {
                text:           root._timeText
                font.pointSize: ScreenTools.smallFontPointSize
                color:          qgcPal.windowTransparentText
            }

            Item { Layout.fillWidth: true }

            QGCLabel {
                text:           root._distanceText
                font.pointSize: ScreenTools.smallFontPointSize
                color:          qgcPal.windowTransparentText
            }
        }

        Item { Layout.fillHeight: true }
    }
}
