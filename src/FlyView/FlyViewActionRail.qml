import QtQuick
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls

/// The action rail: the flight actions in a fixed column down the left edge,
/// always in the same place under the same thumb instead of behind a menu that
/// has to be opened mid-flight.
///
/// v3 floats it over the viewport as four separate buttons, the way Auterion's
/// sidebar and DJI's RTH control sit over the view, rather than as a solid
/// zone the map stops at. Exactly four -- Takeoff, Return, Land, Hold -- with
/// Hold in #b52b2b because it is the one that stops the aircraft.
///
/// Actions grey out rather than disappear when the vehicle cannot accept them.
/// A rail whose buttons move around as flight state changes is a rail you have
/// to look at; one that keeps its shape can be pressed by position.
///
/// The rail is one of the reserved slots: its column is inset from the map's
/// own controls, and nothing else is placed in it.
Item {
    id: root

    property var guidedController: null

    /// One button's edge, and the gap between buttons. Fixed so the slot the
    /// map is inset by never moves.
    readonly property real buttonSize: ScreenTools.defaultFontPixelHeight * 2.0
    readonly property real buttonGap:  ScreenTools.defaultFontPixelHeight * 0.25

    width:  buttonSize
    height: railColumn.height

    readonly property color _danger: "#b52b2b"
    // #20242a at 0.88: the viewport chrome tone.
    readonly property color _chrome: Qt.rgba(0.125, 0.141, 0.165, 0.88)
    readonly property color _chromePressed: Qt.rgba(0.25, 0.28, 0.33, 0.95)

    component RailButton: Rectangle {
        id: btn

        property string label:         ""
        property string iconSource:    ""
        property bool   danger:        false
        property bool   actionEnabled: true

        signal activated()

        width:  root.buttonSize
        height: root.buttonSize
        radius: ScreenTools.defaultFontPixelHeight * 0.19

        color: danger ? root._danger
                      : (railMouse.pressed ? root._chromePressed : root._chrome)
        opacity: actionEnabled ? 1.0 : 0.35

        readonly property color _fg: "white"

        ColumnLayout {
            anchors.centerIn:   parent
            spacing:            ScreenTools.defaultFontPixelHeight * 0.1

            QGCColoredImage {
                Layout.alignment:       Qt.AlignHCenter
                Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 0.85
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
                font.pointSize:     ScreenTools.smallFontPointSize
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

    Column {
        id:         railColumn
        spacing:    root.buttonGap

        RailButton {
            label:          qsTr("Takeoff")
            iconSource:     "/res/takeoff.svg"
            actionEnabled:  root.guidedController ? root.guidedController.showTakeoff : false
            onActivated:    root._confirm(root.guidedController.actionTakeoff)
        }

        // The mission verb. One slot, two states: on the ground with a mission
        // aboard it starts; in the air with waypoints left it continues. Before
        // this the only way to start a mission was the automatic popup, which
        // could not be brought back once dismissed. Resume-after-landing keeps
        // its own dialog (FlyViewMissionCompleteDialog), which appears at the
        // one moment it applies.
        RailButton {
            readonly property bool _continue: root.guidedController ? root.guidedController.showContinueMission : false
            readonly property bool _start:    root.guidedController ? root.guidedController.showStartMission    : false
            label:          _continue ? qsTr("Continue") : qsTr("Start")
            iconSource:     "/res/Play.svg"
            actionEnabled:  _start || _continue
            onActivated:    root._confirm(_continue ? root.guidedController.actionContinueMission
                                                    : root.guidedController.actionStartMission)
        }

        // Change altitude in flight, outside a mission. The strip that carried
        // it was removed with v3; the slider it opens is the takeoff one.
        RailButton {
            label:          qsTr("Altitude")
            iconSource:     "/res/chevron-up.svg"
            actionEnabled:  root.guidedController ? root.guidedController.showChangeAlt : false
            onActivated:    root._confirm(root.guidedController.actionChangeAlt)
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

        // Hold is Pause: it stops the aircraft where it is. Red because it is
        // the one you reach for when something is going wrong.
        RailButton {
            label:          qsTr("Hold")
            iconSource:     "/res/Pause.svg"
            danger:         true
            actionEnabled:  root.guidedController ? root.guidedController.showPause : false
            onActivated:    root._confirm(root.guidedController.actionPause)
        }

        // Emergency Stop is deliberately not on the rail. On a multirotor it is
        // motors-off in flight, which is a crash; Hold is the stop an operator
        // means. The action still exists in GuidedActionsController for the
        // advanced tools. Decision recorded 2026-09-17; reverse it here, not by
        // adding a fifth verb somewhere else.
    }
}
