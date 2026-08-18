import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

Item {
    id: root

    property var vehicle: null

    readonly property real pad: ScreenTools.defaultFontPixelHeight * 0.6
    readonly property real r: ScreenTools.defaultFontPixelHeight * 0.6
    readonly property color glass: Qt.rgba(0, 0, 0, 0.35)
    readonly property color glassBorder: Qt.rgba(1, 1, 1, 0.10)
    readonly property color tick: Qt.rgba(1, 1, 1, 0.55)
    readonly property color tickMinor: Qt.rgba(1, 1, 1, 0.25)
    readonly property color _textColor: "white"
    readonly property real _tickThickness: Math.max(1, ScreenTools.defaultFontPixelHeight * 0.05)

    readonly property real _headingValue: vehicle ? vehicle.heading.rawValue : Number.NaN
    readonly property real _pitchDeg:     _attitudeFactValue(vehicle && vehicle.attitude ? vehicle.attitude.pitch : (vehicle ? vehicle.pitch : null))
    readonly property real _rollDeg:      _attitudeFactValue(vehicle && vehicle.attitude ? vehicle.attitude.roll : (vehicle ? vehicle.roll : null))
    readonly property real _altitudeValue: (vehicle && vehicle.altitudeRelative) ? vehicle.altitudeRelative.rawValue : Number.NaN
    readonly property real _speedValue:   vehicle ? vehicle.groundSpeed.rawValue : Number.NaN

    readonly property bool _headingValid: !_isInvalid(_headingValue)
    readonly property bool _attitudeValid: !_isInvalid(_pitchDeg) && !_isInvalid(_rollDeg)
    readonly property bool _altitudeValid: !_isInvalid(_altitudeValue)
    readonly property bool _speedValid: !_isInvalid(_speedValue)

    function _isInvalid(value) {
        return value === undefined || value === null || isNaN(value)
    }

    function _attitudeFactValue(fact) {
        if (!fact) {
            return Number.NaN
        }
        if (fact.value !== undefined) {
            return fact.value
        }
        if (fact.rawValue !== undefined) {
            return fact.rawValue
        }
        return Number.NaN
    }

    function _normalizeHeading(value) {
        var heading = value % 360
        if (heading < 0) {
            heading += 360
        }
        return heading
    }

    function _headingRounded() {
        return _headingValid ? Math.round(_headingValue) : 0
    }

    function _formatHeading() {
        if (!_headingValid) {
            return qsTr("--")
        }
        return _normalizeHeading(_headingRounded()) + "\u00B0"
    }

    function _formatNumber(value) {
        return _isInvalid(value) ? qsTr("--") : value.toFixed(0)
    }

    readonly property real _tapeWidth: ScreenTools.defaultFontPixelWidth * 6.5
    readonly property real _tapeTickSpacing: ScreenTools.defaultFontPixelHeight * 1.0
    readonly property int _tapeTickCount: 11
    readonly property int _tapeTickMid: Math.floor(_tapeTickCount / 2)

    Rectangle {
        id: compassRibbon
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: ScreenTools.defaultFontPixelHeight * 2.2
        color: glass
        radius: r
        border.color: glassBorder

        Item {
            id: compassTicks
            anchors.fill: parent
            anchors.margins: pad

            readonly property int tickCount: 17
            readonly property int tickStep: 10
            readonly property int tickMid: 8
            readonly property real tickSpacing: width / (tickCount - 1)
            readonly property int centerHeading: _headingRounded()

            Repeater {
                model: compassTicks.tickCount

                Item {
                    width: 1
                    height: compassTicks.height
                    x: index * compassTicks.tickSpacing

                    readonly property int tickValue: _normalizeHeading(compassTicks.centerHeading + (index - compassTicks.tickMid) * compassTicks.tickStep)
                    readonly property bool majorTick: (tickValue % 30) === 0

                    Rectangle {
                        width: _tickThickness
                        height: majorTick ? ScreenTools.defaultFontPixelHeight * 0.9 : ScreenTools.defaultFontPixelHeight * 0.5
                        color: majorTick ? tick : tickMinor
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: _headingValid
                    }

                    QGCLabel {
                        anchors.top: parent.top
                        anchors.topMargin: ScreenTools.defaultFontPixelHeight * 0.9
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: majorTick ? tickValue.toString() : ""
                        color: tick
                        visible: _headingValid && majorTick
                    }
                }
            }
        }

        Rectangle {
            width: ScreenTools.defaultFontPixelWidth * 0.6
            height: ScreenTools.defaultFontPixelHeight * 1.2
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: ScreenTools.defaultFontPixelHeight * 0.2
            color: tick
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            height: ScreenTools.defaultFontPixelHeight * 1.6
            width: ScreenTools.defaultFontPixelWidth * 7
            radius: r
            color: Qt.rgba(0, 0, 0, 0.55)
            border.color: glassBorder

            QGCLabel {
                anchors.centerIn: parent
                text: _formatHeading()
                color: _textColor
            }
        }
    }

    Item {
        id: horizonRoot
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(parent.width * 0.6, ScreenTools.defaultFontPixelHeight * 28)
        height: Math.min(parent.height * 0.55, ScreenTools.defaultFontPixelHeight * 18)

        Rectangle {
            width: parent.width * 0.7
            height: parent.height * 0.7
            anchors.centerIn: parent
            radius: r
            color: glass
            border.color: glassBorder
        }

        Item {
            id: horizonClip
            anchors.fill: parent
            clip: true

            Item {
                id: ladder
                width: horizonClip.width * 2
                height: horizonClip.height * 2
                x: (horizonClip.width - width) / 2
                y: (horizonClip.height - height) / 2 + (_attitudeValid ? _pitchDeg : 0) * _pitchScale
                rotation: _attitudeValid ? -_rollDeg : 0
                visible: _attitudeValid

                readonly property real _pitchScale: ScreenTools.defaultFontPixelHeight * 0.25

                Rectangle {
                    width: ladder.width
                    height: _tickThickness
                    color: tick
                    y: ladder.height / 2
                }

                Repeater {
                    model: [ -30, -20, -10, -5, 5, 10, 20, 30 ]

                    Item {
                        readonly property int tickValue: modelData
                        readonly property bool majorTick: Math.abs(tickValue) >= 10 && (tickValue % 10) === 0
                        width: ladder.width
                        height: ScreenTools.defaultFontPixelHeight
                        y: (ladder.height / 2) - (tickValue * ladder._pitchScale)

                        Rectangle {
                            width: majorTick ? ScreenTools.defaultFontPixelWidth * 10 : ScreenTools.defaultFontPixelWidth * 6
                            height: _tickThickness
                            color: majorTick ? tick : tickMinor
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        QGCLabel {
                            text: majorTick ? Math.abs(tickValue).toString() : ""
                            color: tick
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.left: parent.horizontalCenter
                            anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 5.5
                            visible: majorTick
                        }

                        QGCLabel {
                            text: majorTick ? Math.abs(tickValue).toString() : ""
                            color: tick
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.horizontalCenter
                            anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 5.5
                            visible: majorTick
                        }
                    }
                }
            }

            QGCLabel {
                anchors.centerIn: parent
                text: qsTr("--")
                color: _textColor
                visible: !_attitudeValid
            }
        }
    }

    Item {
        id: altitudeTape
        anchors.left: parent.left
        anchors.verticalCenter: horizonRoot.verticalCenter
        width: _tapeWidth
        height: horizonRoot.height

        Rectangle {
            anchors.fill: parent
            radius: r
            color: glass
            border.color: glassBorder
        }

        Item {
            id: altitudeTicks
            anchors.fill: parent
            anchors.margins: pad
            clip: true

            readonly property real tickStep: Math.abs(_altitudeValue) > 30 ? 5 : 1
            readonly property real baseValue: _altitudeValid ? Math.round(_altitudeValue / tickStep) * tickStep : 0
            readonly property real offset: _altitudeValid ? ((baseValue - _altitudeValue) / tickStep) * _tapeTickSpacing : 0

            Repeater {
                model: _altitudeValid ? _tapeTickCount : 0

                Item {
                    readonly property real tickValue: altitudeTicks.baseValue + (index - _tapeTickMid) * altitudeTicks.tickStep
                    width: parent.width
                    height: _tapeTickSpacing
                    y: (parent.height / 2) + (index - _tapeTickMid) * _tapeTickSpacing + altitudeTicks.offset

                    Rectangle {
                        width: ScreenTools.defaultFontPixelWidth * 2
                        height: _tickThickness
                        color: tick
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    QGCLabel {
                        text: tickValue.toFixed(0)
                        color: tick
                        anchors.left: parent.left
                        anchors.leftMargin: ScreenTools.defaultFontPixelWidth * 2.5
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (pad * 2)
            height: ScreenTools.defaultFontPixelHeight * 2.0
            radius: r
            color: Qt.rgba(0, 0, 0, 0.6)
            border.color: glassBorder

            QGCLabel {
                anchors.centerIn: parent
                text: _altitudeValid ? (_formatNumber(_altitudeValue) + " m") : qsTr("--")
                color: _textColor
            }
        }
    }

    Item {
        id: speedTape
        anchors.right: parent.right
        anchors.verticalCenter: horizonRoot.verticalCenter
        width: _tapeWidth
        height: horizonRoot.height

        Rectangle {
            anchors.fill: parent
            radius: r
            color: glass
            border.color: glassBorder
        }

        Item {
            id: speedTicks
            anchors.fill: parent
            anchors.margins: pad
            clip: true

            readonly property real tickStep: 1
            readonly property real baseValue: _speedValid ? Math.round(_speedValue / tickStep) * tickStep : 0
            readonly property real offset: _speedValid ? ((baseValue - _speedValue) / tickStep) * _tapeTickSpacing : 0

            Repeater {
                model: _speedValid ? _tapeTickCount : 0

                Item {
                    readonly property real tickValue: speedTicks.baseValue + (index - _tapeTickMid) * speedTicks.tickStep
                    width: parent.width
                    height: _tapeTickSpacing
                    y: (parent.height / 2) + (index - _tapeTickMid) * _tapeTickSpacing + speedTicks.offset

                    Rectangle {
                        width: ScreenTools.defaultFontPixelWidth * 2
                        height: _tickThickness
                        color: tick
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    QGCLabel {
                        text: tickValue.toFixed(0)
                        color: tick
                        anchors.right: parent.right
                        anchors.rightMargin: ScreenTools.defaultFontPixelWidth * 2.5
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (pad * 2)
            height: ScreenTools.defaultFontPixelHeight * 2.0
            radius: r
            color: Qt.rgba(0, 0, 0, 0.6)
            border.color: glassBorder

            QGCLabel {
                anchors.centerIn: parent
                text: _speedValid ? (_formatNumber(_speedValue) + " m/s") : qsTr("--")
                color: _textColor
            }
        }
    }
}
