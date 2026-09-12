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
    /// "stop", "avoid", or "" for an ordinary critical message.
    property string _kind:      ""
    property string _lastText:  ""

    readonly property var _activeVehicle: QGroundControl.multiVehicleManager.activeVehicle

    QGCPalette { id: qgcPal }

    /// Decide whether a STATUSTEXT is an avoidance event worth a banner.
    ///
    /// Mirrors ObstacleHUD's classify_avoid_text(). u300-avoid.lua v1.4 sends
    /// one line per event:
    ///     RADAR: FWD 7.3m ofs +5.0 (tot 5.0)   climbed over, still in AUTO
    ///     RADAR: DWN 8.4m LOITER               stopped, needs the pilot
    /// Pre-v1.4 scripts sent "Obstacle Detected"; both are handled. Releases
    /// and routine chatter return null on purpose -- the banner means
    /// "something is in the way", not "the script said something".
    function _classifyAvoid(text) {
        if (!text) {
            return null
        }
        if (text.indexOf("Obstacle Detected") !== -1) {
            return { kind: "stop", label: qsTr("OBSTACLE DETECTED") }
        }
        if (text.indexOf("RADAR:") !== 0) {
            return null
        }
        var body = text.substring(6).replace(/^\s+|\s+$/g, "")
        if (body.indexOf("clear") === 0) {
            return null
        }
        if (body.indexOf("fault:") !== -1) {
            return { kind: "stop", label: qsTr("RADAR SCRIPT FAULT") }
        }
        if (body.indexOf(" ofs +") !== -1) {
            return { kind: "avoid", label: qsTr("AVOIDING \u2014 %1").arg(body) }
        }
        if (body.indexOf("LOITER") !== -1 || body.indexOf("BRAKE") !== -1) {
            return { kind: "stop", label: qsTr("STOPPED \u2014 %1").arg(body) }
        }
        return null
    }

    /// Show a new critical message, folding any still on screen into the count.
    function show(message) {
        var avoid = _classifyAvoid(message)
        if (avoid) {
            _showBanner(avoid.label, avoid.kind, message)
            return
        }
        _showBanner(message, "", message)
    }

    function _showBanner(label, kind, rawText) {
        // The same line can arrive twice -- once as a critical routed from
        // MainWindow and once straight off the STATUSTEXT stream. Showing it
        // again would inflate the "N more" count for one event.
        if (rawText === _lastText && _message !== "") {
            return
        }
        if (_message !== "") {
            _moreCount++
        }
        // A stop outranks whatever is on screen; an ordinary message never
        // displaces one.
        if (_kind === "stop" && kind !== "stop" && _message !== "") {
            _lastText = rawText
            holdTimer.restart()
            return
        }
        _message  = label
        _kind     = kind
        _lastText = rawText
        holdTimer.restart()
    }

    function clear() {
        holdTimer.stop()
        _message   = ""
        _moreCount = 0
        _kind      = ""
        _lastText  = ""
    }

    // Avoidance events are not necessarily CRITICAL severity, so they would
    // never reach the critical-message path. Listen to the raw stream too.
    Connections {
        target: root._activeVehicle
        ignoreUnknownSignals: true
        function onTextMessageReceived(sysid, componentid, severity, text, description) {
            var avoid = root._classifyAvoid(text)
            if (avoid) {
                root._showBanner(avoid.label, avoid.kind, text)
            }
        }
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
        id:             bannerBg
        anchors.fill:   parent
        color:          root._kind === "stop"  ? "#b52b2b"
                            : root._kind === "avoid" ? "#eecc44"
                            : qgcPal.alertBackground
        border.color:   qgcPal.alertBorder
        border.width:   1
        visible:        root.hasMessage

        // A stop banner is red, so its text has to invert to stay readable.
        readonly property color _fg: root._kind === "stop" ? "white" : qgcPal.alertText

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
                color:                  bannerBg._fg
                fillMode:               Image.PreserveAspectFit
            }

            QGCLabel {
                Layout.fillWidth:   true
                Layout.alignment:   Qt.AlignVCenter
                text:               root._message
                color:              bannerBg._fg
                elide:              Text.ElideRight
                maximumLineCount:   1
            }

            QGCLabel {
                Layout.alignment:   Qt.AlignVCenter
                text:               root._moreCount > 0
                                        ? qsTr("%1 more \u00b7 tap to review").arg(root._moreCount)
                                        : qsTr("tap to review")
                color:              bannerBg._fg
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
