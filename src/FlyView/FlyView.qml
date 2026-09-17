import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts

import QtLocation
import QtPositioning
import QtQuick.Window
import QtQml.Models

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FlyView
import QGroundControl.FlightMap
import QGroundControl.UTMSP
import QGroundControl.Viewer3D

Item {
    id: _root

    // These should only be used by MainRootWindow
    property var planController:    _planController
    property var guidedController:  _guidedController

    // Properties of UTM adapter
    property bool utmspSendActTrigger: false

    PlanMasterController {
        id:                     _planController
        flyView:                true
        Component.onCompleted:  start()
    }

    property bool   _mainWindowIsMap:       mapControl.pipState.state === mapControl.pipState.fullState
    property bool   _isFullWindowItemDark:  _mainWindowIsMap ? mapControl.isSatelliteMap : true
    property var    _activeVehicle:         QGroundControl.multiVehicleManager.activeVehicle
    property var    _missionController:     _planController.missionController
    property var    _geoFenceController:    _planController.geoFenceController
    property var    _rallyPointController:  _planController.rallyPointController
    property real   _margins:               ScreenTools.defaultFontPixelWidth / 2
    property var    _guidedController:      guidedActionsController
    property var    _guidedValueSlider:     guidedValueSlider
    property var    _widgetLayer:           widgetLayer
    property real   _toolsMargin:           ScreenTools.defaultFontPixelWidth * 0.75
    // With no video the PFD is PipView's second pane, and the thumbnail goes
    // top-left so it clears the obstacle profile in the bottom-left corner.
    property bool   _pipAtTop:              !QGroundControl.videoManager.hasVideo
    property rect   _centerViewport:        Qt.rect(0, 0, width, height)
    property real   _rightPanelWidth:       ScreenTools.defaultFontPixelWidth * 30
    property var    _mapControl:            mapControl
    property real   _widgetMargin:          ScreenTools.defaultFontPixelWidth * 0.75
    property bool   _fieldModeEnabled:      QGroundControl.settingsManager.appSettings.fieldModeEnabled.value
    property var    _appSettings:           QGroundControl.settingsManager.appSettings
    property bool   _showParameterFavoritesPanel: false

    property real   _fullItemZorder:    0
    property real   _pipItemZorder:     QGroundControl.zOrderWidgets

    // The modern-HUD field default is gone with the HUD it enabled. It wrote
    // modernHudEnabled true the first time Field Mode was switched on and never
    // wrote it back, which is why the bench handheld was left with the HUD on
    // and Field Mode off. Nothing reads the setting now.

    function dropMainStatusIndicatorTool() {
        toolbar.dropMainStatusIndicatorTool();
    }

    /// Show a critical vehicle message in the toolbar banner.
    function showVehicleMessage(message) {
        toolbar.showVehicleMessage(message);
    }

    // v3: the map is the whole screen and every control floats over it in a
    // reserved slot. These insets are those slots, so the map's own controls
    // (scale, zoom, compass) stay clear of them. Every value is derived from
    // the item that occupies the slot, so a resize moves the inset with it.
    QGCToolInsets {
        id:                     _toolInsets
        topEdgeLeftInset:       toolbar.height
        topEdgeCenterInset:     topEdgeLeftInset
        topEdgeRightInset:      topEdgeLeftInset
        leftEdgeTopInset:       actionRail.x + actionRail.width + _toolsMargin
        leftEdgeCenterInset:    leftEdgeTopInset
        leftEdgeBottomInset:    navCard.x + navCard.width + _toolsMargin
        bottomEdgeLeftInset:    navCard.height + _toolsMargin * 2
        bottomEdgeCenterInset:  mapButtons.height + _toolsMargin * 2
        bottomEdgeRightInset:   telemetryCard.height + _toolsMargin * 2
        rightEdgeCenterInset:   videoToggle.width + _toolsMargin * 2.4
    }

    QGCPalette { id: flyViewPal }

    // Was a child of the stock toolbar, which zone 1 replaced. It still overlays
    // the top bar, and is sized by it as before -- the control draws its small
    // bar as a fraction of its own height, so it needs the bar's geometry, not
    // the view's.
    ParameterDownloadProgress {
        anchors.fill:   toolbar
        z:              QGroundControl.zOrderTopMost
    }

    // v3: the map is the whole window. Every control floats over it in a
    // reserved slot -- the layout DJI, Auterion and Skydio converge on -- and
    // the slots are what _toolInsets describes, so the map's own controls stay
    // clear of them. Nothing else may be placed inside a slot.
    Item {
        id:                 mapHolder
        anchors.fill:       parent

        FlyViewMap {
            id:                     mapControl
            planMasterController:   _planController
            rightPanelWidth:        ScreenTools.defaultFontPixelHeight * 9
            pipView:                _pipView
            pipMode:                !_mainWindowIsMap
            toolInsets:             customOverlay.totalToolInsets
            mapName:                "FlightDisplayView"
            enabled:                !viewer3DWindow.isOpen
        }

        FlyViewVideo {
            id:         videoControl
            pipView:    _pipView
        }

        // Stands in as PipView's second pane when there is no video stream, so the
        // primary flight display can trade places with the map.
        FlyViewPfdPane {
            id:         pfdControl
            pipView:    _pipView
            topInset:   toolbar.height
            visible:    !QGroundControl.videoManager.hasVideo
        }

        PipView {
            id:                     _pipView
            anchors.left:           parent.left
            anchors.leftMargin:     _toolsMargin
            anchors.top:            _pipAtTop ? parent.top : undefined
            // mapHolder already starts below the status bar, so adding the bar's
            // height again pushed the thumbnail a full bar down into the map.
            anchors.topMargin:      _toolsMargin
            anchors.bottom:         _pipAtTop ? undefined : parent.bottom
            anchors.bottomMargin:   _toolsMargin
            item1IsFullSettingsKey: "MainFlyWindowIsMap"
            // A flight display needs more pixels than a video thumbnail to read.
            _pipSize:               parent.width * (_pipAtTop ? 0.28 : 0.2)
            item1:                  mapControl
            item2:                  QGroundControl.videoManager.hasVideo ? videoControl : pfdControl
            // Main.dc.html draws no thumbnail over the map, and zone 4 already carries the
            // flight display. Hiding PipView also takes away the triple-chevron handle it
            // parks on the map while collapsed, which was the last thing standing in the
            // map zone. The item stays: mapControl and pfdControl bind to its pipState
            // wiring, and SWAP MAP still calls _swapPip() to trade the full-window pane.
            show:                   false
            z:                      QGroundControl.zOrderWidgets

            // Pushes the takeoff/return column below the thumbnail when it sits top-left.
            property real leftEdgeTopInset:    (visible && _pipAtTop) ? height + anchors.topMargin : 0
            property real leftEdgeBottomInset: (visible && !_pipAtTop) ? width + anchors.leftMargin : 0
            property real bottomEdgeLeftInset: (visible && !_pipAtTop) ? height + anchors.bottomMargin : 0
        }

        // Guided-action confirmation, moved here from the stock toolbar's centre
        // panel when zone 1 replaced it. Main.dc.html has no cell for it, but a
        // confirmation is transient rather than a zone, so it overlays the map
        // and is bounded by mapHolder -- it can never cover the rail, the
        // instrument column or the obstacle band.
        //
        // The message display stays a sibling rather than a child so it is not
        // clipped. The control owns its own fade timer and animation; this file
        // only supplies the item to fade, via messageDisplay.
        GuidedActionConfirm {
            id:                         guidedActionConfirm
            anchors.horizontalCenter:   parent.horizontalCenter
            anchors.top:                parent.top
            anchors.topMargin:          toolbar.height + _toolsMargin
            height:                     toolbar.height
            z:                          QGroundControl.zOrderTopMost
            guidedController:           globals.guidedControllerFlyView
            guidedValueSlider:          _guidedValueSlider
            utmspSliderTrigger:         utmspSendActTrigger
            messageDisplay:             guidedActionMessageDisplay

            // No `visible` binding here on purpose. GuidedActionConfirm already
            // declares its own -- false unless UTMSP is driving it -- and then
            // sets visible imperatively from _reallyShow() and
            // confirmCancelled(). The old binding at this site,
            // `visible: !_fieldModeEnabled`, overrode that default and forced it
            // true whenever Field Mode was off, so an empty confirmation box sat
            // on screen with nothing to confirm. It did the same in the toolbar
            // it came from; it was just less obvious in a corner than it is over
            // the middle of the map.
            //
            // Field Mode no longer suppresses the confirmation as a side effect
            // of that override. If it should, that belongs in the guided
            // controller as a deliberate rule, not in a visibility binding that
            // also breaks the idle state.
        }

        Rectangle {
            id:                         guidedActionMessageDisplay
            anchors.top:                guidedActionConfirm.bottom
            anchors.topMargin:          _toolsMargin
            anchors.horizontalCenter:   parent.horizontalCenter
            width:                      guidedMessageLabel.contentWidth + (_toolsMargin * 2)
            height:                     guidedMessageLabel.contentHeight + (_toolsMargin * 2)
            color:                      flyViewPal.windowTransparent
            radius:                     ScreenTools.defaultBorderRadius
            z:                          QGroundControl.zOrderTopMost
            visible:                    guidedActionConfirm.visible

            QGCLabel {
                id:         guidedMessageLabel
                x:          _toolsMargin
                y:          _toolsMargin
                width:      ScreenTools.defaultFontPixelWidth * 30
                wrapMode:   Text.WordWrap
                text:       guidedActionConfirm.message
            }
        }

        // The PFD/Map swap tab is gone. Zone 4 already carries SWAP MAP in its
        // header, which calls the same _swapPip(), and the artboard draws no
        // button over the map -- two controls for one action, one of them in a
        // zone that does not exist.

        // Centre and Layers, 44px tall, bottom-centre: the one slot the nav card
        // and the telemetry card leave between them.
        Row {
            id:                         mapButtons
            anchors.horizontalCenter:   parent.horizontalCenter
            anchors.bottom:             parent.bottom
            anchors.bottomMargin:       ScreenTools.defaultFontPixelWidth * 1.1
            spacing:                    ScreenTools.defaultFontPixelWidth * 0.6
            z:                          QGroundControl.zOrderWidgets

            Rectangle {
                id:             centreButton
                height:         ScreenTools.defaultFontPixelHeight * 1.5
                width:          Math.max(height, centreLabel.contentWidth + ScreenTools.defaultFontPixelWidth * 2)
                color:          flyViewPal.window
                opacity:        _centreEnabled ? 0.94 : 0.5
                border.color:   flyViewPal.windowShade
                border.width:   1

                // Nothing to centre on without a position, so the button says so
                // by going flat rather than moving the map to nowhere.
                readonly property bool _centreEnabled: _activeVehicle && _activeVehicle.coordinate.isValid

                QGCLabel {
                    id:                 centreLabel
                    anchors.centerIn:   parent
                    text:               qsTr("Centre")
                    color:              flyViewPal.text
                }

                QGCMouseArea {
                    anchors.fill:   parent
                    enabled:        centreButton._centreEnabled
                    onClicked:      mapControl.center = _activeVehicle.coordinate
                }
            }

            Rectangle {
                id:             layersButton
                height:         ScreenTools.defaultFontPixelHeight * 1.5
                width:          Math.max(height, layersLabel.contentWidth + ScreenTools.defaultFontPixelWidth * 2)
                color:          flyViewPal.window
                opacity:        0.94
                border.color:   flyViewPal.windowShade
                border.width:   1

                QGCLabel {
                    id:                 layersLabel
                    anchors.centerIn:   parent
                    text:               qsTr("Layers")
                    color:              flyViewPal.text
                }

                QGCMouseArea {
                    anchors.fill:   parent
                    onClicked:      layersPanel.visible = !layersPanel.visible
                }
            }
        }

        // The map's only layer-like choice is which tile set it draws, so that
        // is what Layers offers. If the design means overlays -- mission,
        // terrain, obstacles -- this is the place to grow them.
        Rectangle {
            id:                         layersPanel
            anchors.horizontalCenter:   mapButtons.horizontalCenter
            anchors.bottom:             mapButtons.top
            anchors.bottomMargin:       ScreenTools.defaultFontPixelWidth * 0.7
            width:                  ScreenTools.defaultFontPixelWidth * 18
            height:                 layersColumn.height + ScreenTools.defaultFontPixelHeight * 0.6
            color:                  flyViewPal.window
            opacity:                0.94
            border.color:           flyViewPal.windowShade
            border.width:           1
            z:                      QGroundControl.zOrderWidgets
            visible:                false

            readonly property var _mapTypeFact:     QGroundControl.settingsManager.flightMapSettings.mapType
            readonly property var _mapProviderFact: QGroundControl.settingsManager.flightMapSettings.mapProvider

            // mapType is a plain string fact with no enums -- the types a
            // provider actually offers come from the map engine, keyed by the
            // provider name, the same way the Map settings page builds its list.
            readonly property var _mapTypes: _mapProviderFact
                                                ? QGroundControl.mapEngineManager.mapTypeList(_mapProviderFact.rawValue)
                                                : []

            Column {
                id:                 layersColumn
                anchors.centerIn:   parent
                width:              parent.width - ScreenTools.defaultFontPixelWidth

                Repeater {
                    model: layersPanel._mapTypes

                    Rectangle {
                        width:      layersColumn.width
                        height:     ScreenTools.defaultFontPixelHeight * 1.4
                        color:      _selected ? flyViewPal.windowShade : "transparent"

                        readonly property bool _selected:
                            layersPanel._mapTypeFact && layersPanel._mapTypeFact.rawValue === modelData

                        QGCLabel {
                            anchors.left:           parent.left
                            anchors.leftMargin:     ScreenTools.defaultFontPixelWidth * 0.5
                            anchors.verticalCenter: parent.verticalCenter
                            text:                   modelData
                            color:                  flyViewPal.text
                        }

                        QGCMouseArea {
                            anchors.fill: parent
                            onClicked: {
                                layersPanel._mapTypeFact.rawValue = modelData
                                layersPanel.visible = false
                            }
                        }
                    }
                }
            }
        }

        FlyViewWidgetLayer {
            id:                     widgetLayer
            anchors.top:            parent.top
            anchors.bottom:         parent.bottom
            anchors.left:           parent.left
            anchors.right:          guidedValueSlider.visible ? guidedValueSlider.left : parent.right
            anchors.margins:        _widgetMargin
            anchors.topMargin:      toolbar.height + _widgetMargin
            // The nav card and the telemetry card own the bottom corners, so the
            // layer's bottom row is reserved to the taller of the two rather than
            // laid out into a slot and covered by it.
            bottomRowReservedHeight: Math.max(navCard.height, telemetryCard.height) +
                                     _widgetMargin
            z:                      _fullItemZorder + 2 // we need to add one extra layer for map 3d viewer (normally was 1)
            parentToolInsets:       _toolInsets
            mapControl:             _mapControl
            visible:                !QGroundControl.videoManager.fullScreen
            isViewer3DOpen:         viewer3DWindow.isOpen
            // The instrument column now carries the flight display permanently,
            // so the map's own rose and values bar are always redundant -- and
            // the artboard draws no instruments over the map at all. This is
            // what that layer's flag already means: the PFD is on screen, so
            // stop repeating it.
            pfdIsMainPane:          true
        }

        FlyViewCustomLayer {
            id:                 customOverlay
            anchors.fill:       widgetLayer
            z:                  _fullItemZorder + 2
            parentToolInsets:   widgetLayer.totalToolInsets
            mapControl:         _mapControl
            visible:            !QGroundControl.videoManager.fullScreen
        }

        // Development tool for visualizing the insets for a paticular layer, show if needed
        FlyViewInsetViewer {
            id:                     widgetLayerInsetViewer
            anchors.top:            parent.top
            anchors.bottom:         parent.bottom
            anchors.left:           parent.left
            anchors.right:          guidedValueSlider.visible ? guidedValueSlider.left : parent.right
            z:                      widgetLayer.z + 1
            insetsToView:           widgetLayer.totalToolInsets
            visible:                false
        }

        GuidedActionsController {
            id:                 guidedActionsController
            missionController:  _missionController
            guidedValueSlider:     _guidedValueSlider
        }

        //-- Guided value slider (e.g. altitude)
        GuidedValueSlider {
            id:                 guidedValueSlider
            anchors.right:      parent.right
            anchors.top:        parent.top
            anchors.bottom:     parent.bottom
            anchors.topMargin:  toolbar.height
            anchors.bottomMargin: _toolInsets.bottomEdgeRightInset
            z:                  QGroundControl.zOrderTopMost
            visible:            false
        }

        Viewer3D {
            id: viewer3DWindow
            anchors.fill: parent
        }
    }

    // ModernHud is gone from the fly view. It was anchored across the whole
    // window between the status bar and the band, drawn over the rail, the map
    // and the instrument column alike -- a zone violation by construction, and
    // a second primary flight display competing with the one zone 4 already
    // draws. Its panels were the translucent "--" boxes sitting over the map.
    //
    // It was also unreachable: modernHudEnabled is turned on once as a side
    // effect of enabling Field Mode and never turned back off, so the bench
    // handheld had it on with fieldModeEnabled false and no control left to
    // clear it.
    //
    // ModernHud.qml is now deleted. Its compass is superseded by the heading
    // strip in zone 4, and its horizon and side tapes only ever restated what
    // that display already draws. The modernHudEnabled settings fact survives
    // in C++ with no reader and no UI; it wants removing with the next change
    // that already has a reason to touch AppSettings.

    // ------------------------------------------------------------ connect state
    // What the screen says before an aircraft is found: one sentence, one
    // instruction, one action -- the companies' strongest stranger-test
    // feature, and the state v1 never drew. The viewport dims under it so the
    // card is the only thing asking for attention; every card and button
    // around it stays in its slot, greyed, so the layout a new pilot learns
    // is the one they will fly with.
    Rectangle {
        id:             connectScrim
        anchors.fill:   parent
        color:          Qt.rgba(0.125, 0.141, 0.165, 0.35)
        z:              QGroundControl.zOrderTopMost + 1
        visible:        !_activeVehicle && !QGroundControl.videoManager.fullScreen

        // Swallow map gestures while the card is up; the map is not the task yet.
        MouseArea { anchors.fill: parent }

        Rectangle {
            id:                 connectCard
            anchors.centerIn:   parent

            // Any saved, operator-made link (the auto-connect UDP entry is dynamic).
            readonly property bool _hasSavedLink: {
                var configs = QGroundControl.linkManager.linkConfigurations
                for (var i = 0; i < configs.count; i++) {
                    if (!configs.get(i).dynamic) {
                        return true
                    }
                }
                return false
            }
            width:              ScreenTools.defaultFontPixelWidth * 34.7
            height:             connectColumn.height + ScreenTools.defaultFontPixelHeight * 1.8
            radius:             ScreenTools.defaultFontPixelHeight * 0.25
            color:              flyViewPal.window

            ColumnLayout {
                id:                 connectColumn
                anchors.centerIn:   parent
                width:              parent.width - ScreenTools.defaultFontPixelWidth * 4
                spacing:            ScreenTools.defaultFontPixelHeight * 0.45

                QGCColoredImage {
                    Layout.alignment:       Qt.AlignHCenter
                    Layout.preferredWidth:  ScreenTools.defaultFontPixelHeight * 2.2
                    Layout.preferredHeight: Layout.preferredWidth
                    sourceSize.height:      Layout.preferredHeight
                    source:                 "/qmlimages/vehicleArrowOpaque.svg"
                    fillMode:               Image.PreserveAspectFit
                    color:                  flyViewPal.text
                }

                QGCLabel {
                    Layout.alignment:   Qt.AlignHCenter
                    text:               qsTr("Connect the aircraft")
                    font.pointSize:     ScreenTools.largeFontPointSize * 1.3
                    font.bold:          true
                    color:              flyViewPal.text
                }

                // True since LinkManager dials the saved Bluetooth links by itself
                // (autoConnectBluetooth). The second line is the dial in progress,
                // so a stranger can tell "looking" from "nothing to look for".
                QGCLabel {
                    Layout.alignment:       Qt.AlignHCenter
                    Layout.fillWidth:       true
                    horizontalAlignment:    Text.AlignHCenter
                    wrapMode:               Text.WordWrap
                    text:                   connectCard._hasSavedLink
                                                ? qsTr("Power on the aircraft. This controller finds it by itself.")
                                                : qsTr("No aircraft link is saved on this controller yet.")
                    color:                  flyViewPal.windowTransparentText
                }

                QGCLabel {
                    Layout.alignment:       Qt.AlignHCenter
                    text:                   QGroundControl.linkManager.bluetoothAutoConnectTarget !== ""
                                                ? qsTr("Looking for %1…").arg(QGroundControl.linkManager.bluetoothAutoConnectTarget)
                                                : qsTr("Waiting for the aircraft…")
                    font.pointSize:         ScreenTools.smallFontPointSize
                    color:                  flyViewPal.windowTransparentText
                    visible:                connectCard._hasSavedLink
                }

                Rectangle {
                    Layout.alignment:       Qt.AlignHCenter
                    Layout.topMargin:       ScreenTools.defaultFontPixelHeight * 0.2
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight * 1.6
                    Layout.preferredWidth:  connectLabel.implicitWidth + ScreenTools.defaultFontPixelWidth * 4
                    radius:                 ScreenTools.defaultFontPixelHeight * 0.19
                    color:                  connectMouse.pressed ? flyViewPal.buttonHighlight : "#3A9BDC"

                    QGCLabel {
                        id:                 connectLabel
                        anchors.centerIn:   parent
                        text:               connectCard._hasSavedLink ? qsTr("Connect manually") : qsTr("Set up the link")
                        font.bold:          true
                        color:              "white"
                    }

                    // Straight to Comm Links, the page with the Connect button, not
                    // to the application menu. showSettingsTool matches the page by
                    // its title, the same way MainStatusIndicatorOfflinePage does.
                    // In Field Mode Settings is closed, so the button opens the
                    // offline status drawer instead: the same saved links, one tap
                    // each, without leaving the fly view.
                    QGCMouseArea {
                        id:             connectMouse
                        anchors.fill:   parent
                        onClicked: {
                            if (_fieldModeEnabled) {
                                dropMainStatusIndicatorTool()
                            } else {
                                mainWindow.showSettingsTool(qsTr("Comm Links"))
                            }
                        }
                    }
                }
            }
        }
    }

    // -------------------------------------------------------------- video toggle
    // DJI's right-edge toggle. With a stream it swaps the map and the video;
    // without one it swaps the map and the flight display, which is what
    // PipView's second pane already is. The label says which, so the button
    // never promises a camera the aircraft does not carry.
    Rectangle {
        id:                     videoToggle
        anchors.right:          parent.right
        anchors.rightMargin:    _toolsMargin * 1.4
        anchors.verticalCenter: parent.verticalCenter
        width:                  ScreenTools.defaultFontPixelHeight * 1.55
        height:                 ScreenTools.defaultFontPixelHeight * 1.8
        radius:                 ScreenTools.defaultFontPixelHeight * 0.19
        color:                  videoMouse.pressed ? Qt.rgba(0.25, 0.28, 0.33, 0.95)
                                                   : Qt.rgba(0.125, 0.141, 0.165, 0.88)
        z:                      QGroundControl.zOrderTopMost
        visible:                !QGroundControl.videoManager.fullScreen && !guidedValueSlider.visible

        QGCLabel {
            anchors.centerIn:   parent
            text:               QGroundControl.videoManager.hasVideo ? qsTr("Video") : qsTr("PFD")
            font.pointSize:     ScreenTools.smallFontPointSize
            color:              _activeVehicle ? "white" : "#6c7175"
        }

        QGCMouseArea {
            id:             videoMouse
            anchors.fill:   parent
            enabled:        _activeVehicle
            onClicked:      _pipView._swapPip()
        }
    }

    UTMSPActivationStatusBar {
        activationStartTimestamp:   UTMSPStateStorage.startTimeStamp
        activationApproval:         UTMSPStateStorage.showActivationTab && QGroundControl.utmspManager.utmspVehicle.vehicleActivation
        flightID:                   UTMSPStateStorage.flightID
        anchors.fill:               parent
        visible:                    !_fieldModeEnabled

        function onActivationTriggered(value) {
            _root.utmspSendActTrigger = value
        }
    }

    // ---------------------------------------------------------- nav card
    // v3: the obstacle band is gone. Its number, its trigger state and the
    // radar it reads moved into a fixed card bottom-left of the viewport --
    // the navigation-display slot DJI Pilot 2 and Auterion both use -- and
    // the along-track profile it drew is one tap away on the card. The next
    // stage adds the heading ring, the forward sensing sector and the
    // vertical obstacle bar around that number.
    FlyViewNavCard {
        id:                     navCard
        anchors.left:           parent.left
        anchors.leftMargin:     actionRail.x + actionRail.width + _toolsMargin * 1.4
        anchors.bottom:         parent.bottom
        anchors.bottomMargin:   _toolsMargin * 1.4
        z:                      QGroundControl.zOrderTopMost
        visible:                !QGroundControl.videoManager.fullScreen
        vehicle:                _activeVehicle
        onProfileRequested:     openObstacleProfile()
    }


    // ------------------------------------------------------------ action rail
    // v3: four floating buttons down the left edge, sized by the rail itself,
    // inset from the bar and the screen edge by the same margin.
    FlyViewActionRail {
        id:                 actionRail
        anchors.left:       parent.left
        anchors.leftMargin: _toolsMargin * 1.4
        anchors.top:        toolbar.bottom
        anchors.topMargin:  _toolsMargin * 1.4
        z:                  QGroundControl.zOrderTopMost
        visible:            !QGroundControl.videoManager.fullScreen
        guidedController:   guidedActionsController
    }

    // ------------------------------------------------------- telemetry card
    // v3: the instrument column is gone. Its four numbers sit bottom-right in
    // a fixed card, where DJI's strip and Auterion's panel both put them; the
    // flight display it carried is one tap away on the Video toggle (later
    // stage), and the mission block's progress moves into the status sentence.
    FlyViewTelemetryCard {
        id:                     telemetryCard
        anchors.right:          parent.right
        anchors.rightMargin:    _toolsMargin * 1.4
        anchors.bottom:         parent.bottom
        anchors.bottomMargin:   _toolsMargin * 1.4
        z:                      QGroundControl.zOrderTopMost
        visible:                !QGroundControl.videoManager.fullScreen
        vehicle:                _activeVehicle
    }

    // v3's status bar: the translucent strip across the top of the viewport
    // carrying the state pill, one status sentence, battery, GNSS and the menu.
    // Still called `toolbar` because every slot in this file insets from it.
    FlyViewStatusBar {
        id:                         toolbar
        visible:                    !QGroundControl.videoManager.fullScreen
        missionController:          _planController.missionController
        onReviewVehicleMessages:    dropMainStatusIndicatorTool()
    }

    function openObstacleProfile() {
        obstacleProfilePopup.vehicle = _activeVehicle
        obstacleProfilePopup.open()
    }

    ObstacleProfilePopup {
        id:     obstacleProfilePopup
        parent: _root
        x:      (_root.width - width) / 2
        y:      (_root.height - height) / 2
    }

    function openMissionQuickVerify() {
        if (!missionVerifyLoader.active) {
            missionVerifyLoader.active = true
            return
        }
        if (missionVerifyLoader.item) {
            missionVerifyLoader.item.open()
        } else {
            missionVerifyLoader.active = false
            missionVerifyLoader.active = true
        }
    }

    Loader {
        id:         missionVerifyLoader
        active:     false
        source:     "qrc:/qml/QGroundControl/FlyView/MissionQuickVerifyDialog.qml"

        onLoaded: {
            item.missionController = _missionController
            item.closed.connect(function() {
                missionVerifyLoader.active = false
            })
            item.open()
        }
    }

    ParameterFavoritesPanel {
        id:                     parameterFavoritesPanel
        anchors.top:            parent.top
        anchors.right:          parent.right
        anchors.bottom:         telemetryCard.top
        anchors.topMargin:      toolbar.height
        anchors.margins:        ScreenTools.defaultFontPixelWidth
        width:                  preferredWidth
        visible:                _showParameterFavoritesPanel && !QGroundControl.videoManager.fullScreen
        vehicle:                _activeVehicle
        panelVisible:           visible
        z:                      QGroundControl.zOrderTopMost
    }
}
