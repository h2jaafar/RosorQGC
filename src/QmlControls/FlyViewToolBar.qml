import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView

Item {
    required property var guidedValueSlider
    required property bool utmspSliderTrigger

    id:     control
    width:  parent.width
    height: ScreenTools.toolbarHeight

    property var    _activeVehicle:     QGroundControl.multiVehicleManager.activeVehicle
    property bool   _communicationLost: _activeVehicle ? _activeVehicle.vehicleLinkManager.communicationLost : false
    property color  _mainStatusBGColor: qgcPal.brandingPurple
    property real   _leftRightMargin:   ScreenTools.defaultFontPixelWidth * 0.75
    property var    _guidedController:  globals.guidedControllerFlyView
    property bool   parameterFavoritesVisible: false

    signal toggleParameterFavorites()
    signal showMissionQuickVerify()
    signal showObstacleProfile()
    signal reviewVehicleMessages()
    property bool   _fieldModeEnabled:  QGroundControl.settingsManager.appSettings.fieldModeEnabled.value
    property bool   _modernHudEnabled:  QGroundControl.settingsManager.appSettings.modernHudEnabled.value

    function dropMainStatusIndicatorTool() {
        mainStatusIndicator.dropMainStatusIndicator();
    }

    /// Show a critical vehicle message in the toolbar instead of a popup.
    function showVehicleMessage(message) {
        vehicleMessageBanner.show(message);
    }

    QGCPalette { id: qgcPal }

    QGCFlickable {
        anchors.fill:       parent
        contentWidth:       toolBarLayout.width
        flickableDirection: Flickable.HorizontalFlick

        Row {
            id:         toolBarLayout
            height:     parent.height
            spacing:    0

            Item {
                id:     leftPanel
                width:  leftPanelLayout.implicitWidth
                height: parent.height

                // Gradient background behind Q button and main status indicator
                Rectangle {
                    id:         gradientBackground
                    height:     parent.height
                    width:      mainStatusLayout.width
                    opacity:    qgcPal.windowTransparent.a

                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0; color: _mainStatusBGColor }
                        //GradientStop { position: qgcButton.x + qgcButton.width; color: _mainStatusBGColor }
                        GradientStop { position: 1; color: qgcPal.window }
                    }
                }

                // Standard toolbar background to the right of the gradient
                Rectangle {
                    anchors.left:   gradientBackground.right
                    anchors.right:  parent.right
                    height:         parent.height
                    color:          qgcPal.windowTransparent
                }

                RowLayout {
                    id:         leftPanelLayout
                    height:     parent.height
                    spacing:    ScreenTools.defaultFontPixelWidth * 0.75

                    // Compact padding for all the toolbar action buttons so they
                    // fit on small/high-DPI screens (e.g. Herelink) without overflow.
                    property real _toolBtnPad: ScreenTools.defaultFontPixelWidth * 0.6

                    RowLayout {
                        id:         mainStatusLayout
                        height:     parent.height
                        spacing:    0

                        QGCToolBarButton {
                            id:                 qgcButton
                            Layout.fillHeight:  true
                            icon.source:        "/res/RosorLogo.png"
                            logo:               true
                            visible:            !_fieldModeEnabled
                            onClicked:          mainWindow.showToolSelectDialog()
                        }

                        MainStatusIndicator {
                            id:                 mainStatusIndicator
                            Layout.fillHeight:  true
                        }
                    }

                    QGCButton {
                        id:         disconnectButton
                        text:       qsTr("Disconnect")
                        leftPadding:  leftPanelLayout._toolBtnPad
                        rightPadding: leftPanelLayout._toolBtnPad
                        onClicked:  _activeVehicle.closeVehicle()
                        visible:    !_fieldModeEnabled && _activeVehicle && _communicationLost
                    }

                    FlightModeIndicator {
                        Layout.fillHeight:  true
                        visible:            _activeVehicle
                    }

                    // Field, Favs and Verify removed: Main.dc.html has five
                    // zones and none of them holds a tool button, so rather
                    // than find them a corner the drawing does not have, they
                    // go. Field mode, the parameter favourites panel and
                    // mission quick-verify are no longer reachable from the fly
                    // view; the panels themselves are untouched and can be put
                    // back behind whatever entry point the design grows.
                }
            }
            Item {
                id:     centerPanel
                // center panel takes up all remaining space in toolbar between left and right panels
                width:  Math.max(guidedActionConfirm.visible ? guidedActionConfirm.width : 0, control.width - (leftPanel.width + rightPanel.width))
                height: parent.height

                Rectangle {
                    anchors.fill:   parent
                    color:          qgcPal.windowTransparent
                }

                GuidedActionConfirm {
                    id:                         guidedActionConfirm
                    height:                     parent.height
                    anchors.horizontalCenter:   parent.horizontalCenter
                    guidedController:           control._guidedController
                    guidedValueSlider:          control.guidedValueSlider
                    utmspSliderTrigger:         control.utmspSliderTrigger
                    messageDisplay:             guidedActionMessageDisplay
                    visible:                    !_fieldModeEnabled
                }

                // Confirming a guided action is a deliberate act and owns the
                // centre of the bar while it is up; the banner waits its turn.
                VehicleMessageBanner {
                    id:                 vehicleMessageBanner
                    anchors.fill:       parent
                    anchors.margins:    ScreenTools.defaultFontPixelHeight * 0.15
                    visible:            !guidedActionConfirm.visible
                    onReviewRequested:  control.reviewVehicleMessages()
                }
            }

            Item {
                id:     rightPanel
                width:  flyViewIndicators.width
                height: parent.height
                visible: !_fieldModeEnabled

                Rectangle {
                    anchors.fill:   parent
                    color:          qgcPal.windowTransparent
                }

                FlyViewToolBarIndicators {
                    id:     flyViewIndicators
                    height: parent.height
                }
            }
        }
    }

    // The guided action message display is outside of the GuidedActionConfirm control so that it doesn't end up as
    // part of the Flickable
    Rectangle {
        id:                         guidedActionMessageDisplay
        anchors.top:                control.bottom
        anchors.topMargin:          _margins
        x:                          control.mapFromItem(guidedActionConfirm.parent, guidedActionConfirm.x, 0).x + (guidedActionConfirm.width - guidedActionMessageDisplay.width) / 2
        width:                      messageLabel.contentWidth + (_margins * 2)
        height:                     messageLabel.contentHeight + (_margins * 2)
        color:                      qgcPal.windowTransparent
        radius:                     ScreenTools.defaultBorderRadius
        visible:                    guidedActionConfirm.visible

        QGCLabel {
            id:         messageLabel
            x:          _margins
            y:          _margins
            width:      ScreenTools.defaultFontPixelWidth * 30
            wrapMode:   Text.WordWrap
            text:       guidedActionConfirm.message
        }

        PropertyAnimation {
            id:         messageOpacityAnimation
            target:     guidedActionMessageDisplay
            property:   "opacity"
            from:       1
            to:         0
            duration:   500
        }

        Timer {
            id:             messageFadeTimer
            interval:       4000
            onTriggered:    messageOpacityAnimation.start()
        }
    }

    ParameterDownloadProgress {
        anchors.fill: parent
    }
}
