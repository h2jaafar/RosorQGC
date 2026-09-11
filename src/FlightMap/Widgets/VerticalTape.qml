import QtQuick

import QGroundControl
import QGroundControl.Controls

// Mission Planner style vertical tape: a scrolling scale with the current
// value boxed at the centre line. Used for the speed and altitude tapes of
// PrimaryFlightDisplay.qml.
Rectangle {
    id:    root
    color: tapeColor

    property real   value:          0
    property int    tickStep:       5     ///< units between labelled ticks
    property real   pixelsPerUnit:  6     ///< vertical pixels per unit of value
    property bool   boxOnRight:     true  ///< which side the value box points to
    property color  tapeColor:      Qt.rgba(0, 0, 0, 0.45)
    property color  boxColor:       Qt.rgba(0, 0, 0, 0.75)
    property color  textColor:      "white"
    property string caption:        ""

    /// Lower bound for the scale. Groundspeed can't go negative, so its tape
    /// shouldn't draw -5/-10 ticks; altitude is left unbounded because relative
    /// altitude legitimately goes below the home point.
    property real   minValue:       -Infinity

    /// Label sizes, so the tape stays legible when the PFD is shown as a small
    /// PipView thumbnail rather than full screen.
    property real   labelPointSize: ScreenTools.smallFontPointSize
    property real   valuePointSize: ScreenTools.defaultFontPointSize

    property bool   _valid:         !isNaN(value) && isFinite(value)
    property real   _value:         _valid ? value : 0
    // Tick nearest the current value; the window is drawn either side of it.
    property int    _centerTick:    Math.round(_value / tickStep) * tickStep

    QGCLabel {
        id:                       captionLabel
        anchors.top:              parent.top
        anchors.topMargin:        1
        anchors.horizontalCenter: parent.horizontalCenter
        text:                     root.caption
        font.pointSize:           root.labelPointSize
        color:                    root.textColor
        z:                        2
    }

    Item {
        anchors.fill: parent
        clip:         true

        Repeater {
            model: 15
            delegate: Item {
                property int  tickValue: root._centerTick + ((index - 7) * root.tickStep)
                property real centerY:   (root.height / 2) + ((root._value - tickValue) * root.pixelsPerUnit)

                x:       0
                y:       centerY - (height / 2)
                width:   root.width
                height:  ScreenTools.defaultFontPixelHeight
                visible: root._valid && tickValue >= root.minValue &&
                         centerY > -height && centerY < root.height + height

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left:           root.boxOnRight ? undefined : parent.left
                    anchors.right:          root.boxOnRight ? parent.right : undefined
                    width:                  ScreenTools.defaultFontPixelWidth
                    height:                 1
                    color:                  root.textColor
                }

                QGCLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left:           root.boxOnRight ? parent.left : undefined
                    anchors.right:          root.boxOnRight ? undefined : parent.right
                    anchors.leftMargin:     root.boxOnRight ? ScreenTools.defaultFontPixelWidth * 1.5 : 0
                    anchors.rightMargin:    root.boxOnRight ? 0 : ScreenTools.defaultFontPixelWidth * 1.5
                    text:                   tickValue.toString()
                    font.pointSize:         root.labelPointSize
                    color:                  root.textColor
                }
            }
        }
    }

    // Centre line
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left:           parent.left
        anchors.right:          parent.right
        height:                 1
        color:                  root.textColor
        opacity:                0.6
    }

    // Current value box
    Rectangle {
        id:                     valueBox
        anchors.verticalCenter: parent.verticalCenter
        anchors.left:           parent.left
        anchors.right:          parent.right
        height:                 ScreenTools.defaultFontPixelHeight * 1.3
        color:                  root.boxColor
        border.color:           root.textColor
        border.width:           1

        QGCLabel {
            anchors.centerIn: parent
            text:             root._valid ? root._value.toFixed(root._value < 100 ? 1 : 0) : qsTr("--")
            color:            root.textColor
            font.pointSize:   root.valuePointSize
        }
    }
}
