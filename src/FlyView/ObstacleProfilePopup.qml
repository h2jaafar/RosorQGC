import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Popup {
    id: root

    property var vehicle: null
    property real maxRangeM: 60.0
    property int viewMode: 0     // 0 = SIDE (elevation), 1 = TOP (azimuth)

    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    width:  parent ? parent.width  * 0.95 : 900
    height: parent ? parent.height * 0.90 : 500

    background: Rectangle {
        anchors.fill: parent
        color: qgcPal.window
        border.color: qgcPal.windowShade
        radius: ScreenTools.defaultBorderRadius
    }

    QGCPalette { id: qgcPal }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: ScreenTools.defaultFontPixelWidth
        spacing: ScreenTools.defaultFontPixelHeight * 0.5

        RowLayout {
            Layout.fillWidth: true
            spacing: ScreenTools.defaultFontPixelWidth

            QGCLabel {
                text: qsTr("Obstacle Profile")
                font.pointSize: ScreenTools.largeFontPointSize
                font.bold: true
                Layout.fillWidth: true
            }

            QGCButton {
                text: "−"
                enabled: root.maxRangeM < 300
                onClicked: root.maxRangeM = Math.min(300, root.maxRangeM * 1.5)
            }

            QGCLabel {
                text: root.maxRangeM.toFixed(0) + " m"
                Layout.minimumWidth: ScreenTools.defaultFontPixelWidth * 6
                horizontalAlignment: Text.AlignHCenter
            }

            QGCButton {
                text: "+"
                enabled: root.maxRangeM > 5
                onClicked: root.maxRangeM = Math.max(5, root.maxRangeM / 1.5)
            }

            QGCButton {
                text: root.viewMode === 0 ? qsTr("Side (elevation)") : qsTr("Top (azimuth)")
                onClicked: root.viewMode = (root.viewMode + 1) % 2
            }

            QGCButton {
                text: qsTr("Close")
                onClicked: root.close()
            }
        }

        ObstacleProfileView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            vehicle: root.vehicle
            maxRangeM: root.maxRangeM
            viewMode: root.viewMode
            labelFontPointSize: ScreenTools.defaultFontPointSize
        }
    }
}
