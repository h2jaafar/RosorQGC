import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// The artboard's action rail: a fixed column down the left edge holding the
/// flight actions, so they are always in the same place under the same thumb
/// instead of behind a menu that has to be opened mid-flight.
///
/// Main.dc.html draws exactly four -- Takeoff, Return, Land, Hold -- with Hold
/// in #b52b2b because it is the one that stops the aircraft. It does not say
/// where the fork's Field / Favs / Verify entries belong, nor the rest of the
/// guided actions, and none of them can simply be deleted to make a layout
/// match. They sit below a divider as compact secondary entries: the rail stays
/// "everything you press", and the drawing's four keep the visual weight.
///
/// Actions grey out rather than disappear when the vehicle cannot accept them.
/// A rail whose buttons move around as flight state changes is a rail you have
/// to look at; one that keeps its shape can be pressed by position.
Rectangle {
    id: root

    property var  guidedController:  null
    property bool fieldModeEnabled:  false

    signal fieldRequested()
    signal favsRequested()
    signal verifyRequested()

    color: qgcPal.window

    QGCPalette { id: qgcPal }

    readonly property color _danger: "#b52b2b"

    // border-right 2px #c9ccce in the artboard.
    Rectangle {
        anchors.right:  parent.right
        anchors.top:    parent.top
        anchors.bottom: parent.bottom
        width:          2
        color:          qgcPal.windowShade
        z:              10
    }

    component RailButton: Rectangle {
        id: btn

        property string label:       ""
        property string iconSource:  ""
        property bool   danger:      false
        property bool   compact:     false
        property bool   actionEnabled: true

        signal activated()

        Layout.fillWidth:       true
        Layout.fillHeight:      !compact
        Layout.preferredHeight: compact ? ScreenTools.defaultFontPixelHeight * 2.4 : 0

        color: danger ? root._danger
                      : (railMouse.pressed ? qgcPal.buttonHighlight : qgcPal.windowShadeLight)
        opacity: actionEnabled ? 1.0 : 0.35

        readonly property color _fg: danger ? "white" : qgcPal.text

        ColumnLayout {
            anchors.centerIn:   parent
            spacing:            ScreenTools.defaultFontPixelHeight * 0.15

            QGCColoredImage {
                Layout.alignment:       Qt.AlignHCenter
                Layout.preferredWidth:  btn.compact ? ScreenTools.defaultFontPixelHeight * 0.9
                                                    : ScreenTools.defaultFontPixelHeight * 1.4
                Layout.preferredHeight: Layout.preferredWidth
                sourceSize.height:      Layout.preferredHeight
                source:                 btn.iconSource
                color:                  btn._fg
                fillMode:               Image.PreserveAspectFit
                visible:                btn.iconSource !== ""
            }

            QGCLabel {
                Layout.alignment:   Qt.AlignHCenter
                text:               btn.label
                font.pointSize:     btn.compact ? ScreenTools.smallFontPointSize
                                                : ScreenTools.defaultFontPointSize
                color:              btn._fg
            }
        }

        MouseArea {
            id:             railMouse
            anchors.fill:   parent
            enabled:        btn.actionEnabled
            onClicked:      btn.activated()
        }
    }

    function _confirm(actionId) {
        if (root.guidedController) {
            root.guidedController.closeAll()
            root.guidedController.confirmAction(actionId)
        }
    }

    ColumnLayout {
        anchors.fill:           parent
        anchors.rightMargin:    2       // clear the border
        spacing:                2

        RailButton {
            label:          qsTr("Takeoff")
            iconSource:     "/res/takeoff.svg"
            actionEnabled:  root.guidedController ? root.guidedController.showTakeoff : false
            onActivated:    root._confirm(root.guidedController.actionTakeoff)
        }

        RailButton {
            label:          qsTr("Return")
            iconSource:     "/res/rtl.svg"
            actionEnabled:  root.guidedController ? root.guidedController.showRTL : false
            onActivated:    root._confirm(root.guidedController.actionRTL)
        }

        RailButton {
            label:          qsTr("Land")
            iconSource:     "/res/land.svg"
            actionEnabled:  root.guidedController ? root.guidedController.showLand : false
            onActivated:    root._confirm(root.guidedController.actionLand)
        }

        // Hold is Pause: it stops the aircraft where it is. Red in the artboard,
        // and red here, because it is the one you reach for when something is
        // going wrong.
        RailButton {
            label:          qsTr("Hold")
            iconSource:     "/res/Pause.svg"
            danger:         true
            actionEnabled:  root.guidedController ? root.guidedController.showPause : false
            onActivated:    root._confirm(root.guidedController.actionPause)
        }

        Rectangle {
            Layout.fillWidth:       true
            Layout.preferredHeight: 2
            color:                  qgcPal.windowShade
        }

        // Not in the drawing. Kept because they are fork features with no other
        // home, and compact so they read as secondary to the four above. The
        // remaining guided actions are not duplicated here -- the tool strip in
        // the map zone still carries them.
        RailButton {
            compact:        true
            label:          qsTr("Field")
            color:          root.fieldModeEnabled ? qgcPal.buttonHighlight : qgcPal.windowShadeLight
            onActivated:    root.fieldRequested()
        }

        RailButton {
            compact:        true
            label:          qsTr("Favs")
            onActivated:    root.favsRequested()
        }

        RailButton {
            compact:        true
            label:          qsTr("Verify")
            onActivated:    root.verifyRequested()
        }
    }
}
