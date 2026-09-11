import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// Critical vehicle messages shown as a strip inside the toolbar instead of a
/// popup over the map.
///
/// A popup in the middle of the fly view covers exactly what the pilot is
/// looking at, and a vehicle sitting with a standing fault -- a bad compass, no
/// GPS lock on the bench -- repeats criticals every few seconds, so the popup
/// never stays closed. The banner keeps the newest message readable, counts the
/// ones that arrived behind it, and gets out of the way on its own.
Item {
    id: root

    /// Emitted when the pilot taps the banner to read the full message list.
    signal reviewRequested()

    readonly property bool hasMessage: _message !== ""

    property string _message:   ""
    property int    _moreCount: 0

    QGCPalette { id: qgcPal }

    /// Show a new critical message, folding any still on screen into the count.
    function show(message) {
        if (_message !== "") {
            _moreCount++
        }
        _message = message
        holdTimer.restart()
    }

    function clear() {
        holdTimer.stop()
        _message   = ""
        _moreCount = 0
    }

    // Long enough to read a line at arm's length, short enough that a repeating
    // fault doesn't leave the bar permanently yellow.
    Timer {
        id:             holdTimer
        interval:       12000
        repeat:         false
        onTriggered:    root.clear()
    }

    Rectangle {
        anchors.fill:   parent
        color:          qgcPal.alertBackground
        border.color:   qgcPal.alertBorder
        border.width:   1
        visible:        root.hasMessage

        RowLayout {
            anchors.fill:           parent
            anchors.leftMargin:     ScreenTools.defaultFontPixelWidth
            anchors.rightMargin:    ScreenTools.defaultFontPixelWidth
            spacing:                ScreenTools.defaultFontPixelWidth

            // Sized through Layout.preferred*: inside a RowLayout a plain
            // width/height is overridden by the item's implicit size, which for
            // an Image is the source's pixel size.
            QGCColoredImage {
                Layout.alignment:       Qt.AlignVCenter
                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight
                Layout.preferredHeight: Layout.preferredWidth
                sourceSize.height:      ScreenTools.defaultFontPixelHeight
                source:                 "/res/VehicleMessages.png"
                color:                  qgcPal.alertText
                fillMode:               Image.PreserveAspectFit
            }

            QGCLabel {
                Layout.fillWidth:   true
                Layout.alignment:   Qt.AlignVCenter
                text:               root._message
                color:              qgcPal.alertText
                elide:              Text.ElideRight
                maximumLineCount:   1
            }

            QGCLabel {
                Layout.alignment:   Qt.AlignVCenter
                text:               root._moreCount > 0
                                        ? qsTr("%1 more \u00b7 tap to review").arg(root._moreCount)
                                        : qsTr("tap to review")
                color:              qgcPal.alertText
                font.pointSize:     ScreenTools.smallFontPointSize
            }
        }

        QGCMouseArea {
            anchors.fill: parent
            onClicked: {
                root.clear()
                root.reviewRequested()
            }
        }
    }
}
