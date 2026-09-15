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

    QGCToolInsets {
        id:                     _toolInsets
        topEdgeLeftInset:       toolbar.height
        topEdgeCenterInset:     topEdgeLeftInset
        topEdgeRightInset:      topEdgeLeftInset
        leftEdgeTopInset:       _pipView.leftEdgeTopInset
        leftEdgeBottomInset:    _pipView.leftEdgeBottomInset
        bottomEdgeLeftInset:    _pipView.bottomEdgeLeftInset
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

    // The map's zone, not the whole window. Main.dc.html's rule is five fixed
    // zones that cannot overlap, so the map is bounded by the rail, the column,
    // the status bar and the obstacle band rather than running underneath them
    // and relying on insets to keep its content clear.
    Item {
        id:                 mapHolder
        anchors.left:       actionRail.right
        anchors.right:      instrumentColumn.left
        anchors.top:        toolbar.bottom
        anchors.bottom:     obstacleBand.top

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
            show:                   QGroundControl.videoManager.hasVideo
                                        ? (!QGroundControl.videoManager.fullScreen &&
                                           (videoControl.pipState.state === videoControl.pipState.pipState || mapControl.pipState.state === mapControl.pipState.pipState))
                                        : (pfdControl.pipState.state === pfdControl.pipState.pipState || mapControl.pipState.state === mapControl.pipState.pipState)
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
            anchors.topMargin:          _toolsMargin
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

        // Artboard: Centre and Layers, bottom-left of the map, 44px tall. The
        // only two controls the drawing puts over the map at all.
        Row {
            anchors.left:       parent.left
            anchors.bottom:     parent.bottom
            anchors.margins:    ScreenTools.defaultFontPixelWidth * 1.1
            spacing:            ScreenTools.defaultFontPixelWidth * 0.6
            z:                  QGroundControl.zOrderWidgets

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
            id:                     layersPanel
            anchors.left:           parent.left
            anchors.bottom:         parent.bottom
            anchors.leftMargin:     ScreenTools.defaultFontPixelWidth * 1.1
            anchors.bottomMargin:   ScreenTools.defaultFontPixelHeight * 1.5 +
                                        ScreenTools.defaultFontPixelWidth * 1.8
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
            // The obstacle band is drawn at zOrderTopMost, so anything laid out
            // underneath it is not merely cramped, it is covered: the compass
            // rose and the values bar were being positioned into the band's
            // rows and hidden by it. It is the only bottom strip now that the
            // critical status bar has moved into zone 1.
            bottomRowReservedHeight: (obstacleBand ? obstacleBand.height : 0) +
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
    // clear it. ModernHud.qml and the setting are untouched.

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

    // The critical status bar is gone. Main.dc.html has five zones and none of
    // them is a strip along the bottom of the window: battery, GPS/RTK and EKF
    // belong to zone 1 and are drawn there now rather than in two places at
    // once, and the radar altitude and obstacle rate it also carried are
    // already in the band below.
    //
    // CriticalStatusBar.qml itself is untouched. The one thing it carried that
    // nothing replaces is the configurable named-float row, which the artboard
    // has no zone for; it can be put back behind whatever the design grows.

    // Obstacle band: a full-width strip along the bottom of the view. The
    // closest-obstacle distance is the largest number on the
    // screen because it is the one that decides whether to stop.
    //
    // Fully opaque on purpose. The band sits over the map at zOrderTopMost, and
    // on the 7" handheld even a few percent of translucency lets the satellite
    // imagery, the compass rose and the values bar read straight through the
    // one readout the pilot cannot afford to squint at. Verified on the bench
    // 2026-09-14: at opacity 0.94 the rose and the values grid were legible
    // through the terrain fill.
    Rectangle {
        id:                     obstacleBand
        anchors.left:           parent.left
        anchors.right:          parent.right
        anchors.bottom:         parent.bottom
        // 168 of 800 in the artboard.
        height:                 ScreenTools.defaultFontPixelHeight * 5.8
        z:                      QGroundControl.zOrderTopMost
        color:                  qgcPal.window

        // Design palette. The artboard's note records these as taken from
        // QGCPalette.cc, so surfaces and text come from qgcPal and follow the
        // Indoor/Outdoor theme, while the four semantic accents are fixed:
        // they mean danger / good / alert / action wherever they appear.
        readonly property color _danger:  "#b52b2b"
        readonly property color _good:    "#008f2d"
        readonly property color _alert:   "#eecc44"
        readonly property color _accent:  "#3A9BDC"

        QGCPalette { id: qgcPal }

        // Border-top 2px #c9ccce in the artboard.
        Rectangle {
            anchors.left:   parent.left
            anchors.right:  parent.right
            anchors.top:    parent.top
            height:         2
            color:          qgcPal.windowShade
        }

        readonly property var _bandNamed: (_activeVehicle && _activeVehicle.namedValueFloats)
                                            ? _activeVehicle.namedValueFloats.values
                                            : ({})

        function _named(key, minValue) {
            var e = obstacleBand._bandNamed && obstacleBand._bandNamed[key]
            if (e && typeof e === "object" && e.value !== undefined && e.value > minValue) {
                return e.value
            }
            return NaN
        }

        readonly property real _closest:  _named("O_C1M", 0.01)
        readonly property real _radarAlt: _named("U3M", 0.2)

        // The stop distance comes off the aircraft, never from a local guess.
        RadarAvoidParams {
            id:      radarParams
            vehicle: _activeVehicle
        }

        /// Inside the trigger only when the trigger is actually known AND the
        /// script is enabled. Unknown stays neutral rather than alarming.
        ///
        /// Latched with the script's own hysteresis: it arms at RADAR_FWD_M and
        /// releases only past RADAR_FWD_M + AVOID_CLEAR_MARGIN_M -- the same two
        /// distances u300-avoid.lua uses, so the chip and the aircraft agree. A
        /// bare "closest <= trigger" test chatters while a return sits on the
        /// threshold, which on a stop indicator reads as the aircraft changing
        /// its mind.
        property bool _insideTrigger: false

        function _updateInsideTrigger() {
            if (!radarParams.haveTrigger || radarParams.avoidEnabled === false ||
                    isNaN(obstacleBand._closest)) {
                obstacleBand._insideTrigger = false
            } else if (obstacleBand._insideTrigger) {
                if (obstacleBand._closest > radarParams.clearM) {
                    obstacleBand._insideTrigger = false
                }
            } else if (obstacleBand._closest <= radarParams.fwdTrigM) {
                obstacleBand._insideTrigger = true
            }
        }

        on_ClosestChanged: obstacleBand._updateInsideTrigger()

        Connections {
            target: radarParams
            ignoreUnknownSignals: true
            function onFwdTrigMChanged()     { obstacleBand._updateInsideTrigger() }
            function onHaveTriggerChanged()  { obstacleBand._updateInsideTrigger() }
            function onAvoidEnabledChanged() { obstacleBand._updateInsideTrigger() }
        }


        /// The cell's footer row in the artboard: "RDR 11.8 m" and "12 Hz".
        ///
        /// Height above ground is deliberately not here. The artboard gives AGL
        /// its own cell in the instrument column, next to ground and vertical
        /// speed, which is where a pilot reads it alongside the other rates
        /// rather than inside the obstacle readout.
        readonly property real _obstacleHz: _named("O_HZ", -1)

        readonly property string _rdrText: isNaN(obstacleBand._radarAlt)
                                            ? qsTr("RDR —")
                                            : qsTr("RDR %1 m").arg(obstacleBand._radarAlt.toFixed(1))

        readonly property string _hzText: isNaN(obstacleBand._obstacleHz)
                                            ? qsTr("— Hz")
                                            : qsTr("%1 Hz").arg(obstacleBand._obstacleHz.toFixed(0))

        /// Drawn on the profile as "trigger 25 m", where the artboard puts it --
        /// against the line it describes, not in the numbers cell.
        readonly property string _triggerText: {
            if (radarParams.avoidEnabled === false) {
                return qsTr("avoid off")
            }
            if (!radarParams.haveTrigger) {
                return ""
            }
            return qsTr("trigger %1 m").arg(radarParams.fwdTrigM.toFixed(0))
        }

        // ------------------------------------------------ closest-obstacle cell
        //
        // Artboard: a 210px cell with 10/14 padding and 6px gaps -- label, the
        // 52px distance, a full-width INSIDE TRIGGER chip, and RDR with the
        // obstacle update rate justified across the footer.
        Rectangle {
            id:                 closestCell
            anchors.left:       parent.left
            anchors.top:        parent.top
            anchors.topMargin:  2               // clear the band's top border
            anchors.bottom:     parent.bottom
            width:              ScreenTools.defaultFontPixelWidth * 14.5
            color:              qgcPal.window

            // border-right 1px #dfe1e3
            Rectangle {
                anchors.right:  parent.right
                anchors.top:    parent.top
                anchors.bottom: parent.bottom
                width:          1
                color:          qgcPal.windowShade
            }

            ColumnLayout {
                anchors.fill:           parent
                anchors.leftMargin:     ScreenTools.defaultFontPixelWidth
                anchors.rightMargin:    ScreenTools.defaultFontPixelWidth
                anchors.topMargin:      ScreenTools.defaultFontPixelHeight * 0.3
                anchors.bottomMargin:   ScreenTools.defaultFontPixelHeight * 0.3
                spacing:                ScreenTools.defaultFontPixelHeight * 0.2

                QGCLabel {
                    Layout.fillWidth:   true
                    text:               qsTr("CLOSEST OBSTACLE")
                    font.pointSize:     ScreenTools.smallFontPointSize
                    color:              qgcPal.windowTransparentText
                }

                // RowLayout, not Row: the unit sits on the big number's
                // baseline, and anchors are not to be mixed with a positioner.
                RowLayout {
                    Layout.fillWidth:   true
                    spacing:            ScreenTools.defaultFontPixelWidth * 0.4

                    QGCLabel {
                        Layout.alignment:   Qt.AlignBaseline
                        text:               isNaN(obstacleBand._closest)
                                                ? "—"
                                                : obstacleBand._closest.toFixed(1)
                        font.pointSize:     ScreenTools.largeFontPointSize * 1.9
                        font.bold:          true
                        color:              obstacleBand._insideTrigger ? obstacleBand._danger
                                                                        : qgcPal.text
                    }

                    QGCLabel {
                        Layout.alignment:   Qt.AlignBaseline
                        text:               qsTr("m")
                        font.pointSize:     ScreenTools.defaultFontPointSize
                        color:              qgcPal.windowTransparentText
                        visible:            !isNaN(obstacleBand._closest)
                    }

                    Item { Layout.fillWidth: true }
                }

                // Full width, as drawn. A stop indicator sized to its own text
                // reads as a label; sized to the cell it reads as a state.
                Rectangle {
                    id:                     insideTriggerChip
                    Layout.fillWidth:       true
                    Layout.preferredHeight: ScreenTools.defaultFontPixelHeight
                    visible:                obstacleBand._insideTrigger
                    color:                  obstacleBand._danger

                    QGCLabel {
                        anchors.centerIn:   parent
                        text:               qsTr("INSIDE TRIGGER")
                        font.pointSize:     ScreenTools.smallFontPointSize
                        font.bold:          true
                        color:              "white"
                    }
                }

                Item { Layout.fillHeight: true }

                RowLayout {
                    Layout.fillWidth:   true
                    spacing:            0

                    QGCLabel {
                        // Amber while the downward radar is locked on the slung
                        // load: the number is the tether, not the ground.
                        text:           obstacleBand._rdrText
                        font.pointSize: ScreenTools.smallFontPointSize
                        color:          obstacleProfile.birdLocked ? obstacleBand._alert
                                                                   : qgcPal.windowTransparentText
                    }

                    Item { Layout.fillWidth: true }

                    QGCLabel {
                        text:           obstacleBand._hzText
                        font.pointSize: ScreenTools.smallFontPointSize
                        color:          qgcPal.windowTransparentText
                    }
                }
            }
        }

        // ------------------------------------------------------ profile itself
        //
        // The one dark surface in the artboard. Terrain and returns are drawn
        // light on dark, so the panel stays #20242a in either theme rather than
        // following qgcPal -- inverting it would invert the plot with it.
        Rectangle {
            anchors.left:       closestCell.right
            anchors.right:      parent.right
            anchors.top:        parent.top
            anchors.topMargin:  2               // clear the band's top border
            anchors.bottom:     parent.bottom
            color:              "#20242a"

            ObstacleTerrainProfile {
                id:                 obstacleProfile
                anchors.fill:       parent
                anchors.margins:    ScreenTools.defaultFontPixelWidth * 0.3
                vehicle:            _activeVehicle
                showGrid:           true
                showLabels:         true
                labelFontPointSize: ScreenTools.smallFontPointSize
                triggerM:           radarParams.avoidEnabled === false ? NaN : radarParams.fwdTrigM
                downFloorM:         radarParams.dwnFloorM
                stopModeLabel:      radarParams.haveTrigger ? radarParams.stopModeName : ""
                ignoreRangeM:       radarParams.ignoreRangeM
                ignoreHalfWidthM:   radarParams.ignoreHalfWidthM
            }

            QGCLabel {
                anchors.left:       parent.left
                anchors.top:        parent.top
                anchors.margins:    ScreenTools.defaultFontPixelWidth * 0.6
                text:               qsTr("OBSTACLE PROFILE · ALONG TRACK ±30 m")
                font.pointSize:     ScreenTools.smallFontPointSize
                color:              "#8d959d"
            }

            // The artboard states the trigger distance here, against the line it
            // describes, in #b52b2b so it reads as the limit rather than a
            // caption. Blank when the vehicle has not told us one.
            QGCLabel {
                anchors.right:      parent.right
                anchors.top:        parent.top
                anchors.margins:    ScreenTools.defaultFontPixelWidth * 0.6
                text:               obstacleBand._triggerText
                visible:            text !== ""
                font.pointSize:     ScreenTools.smallFontPointSize
                color:              obstacleBand._danger
            }
        }

        // Tap anywhere on the band for the full popup with zoom controls.
        MouseArea {
            id:             bandMouse
            anchors.fill:   parent
            onClicked:      openObstacleProfile()
        }

        Rectangle {
            anchors.fill:   parent
            color:          "transparent"
            border.color:   bandMouse.pressed ? Qt.rgba(1, 0.6, 0, 0.7) : Qt.rgba(1, 1, 1, 0.18)
            border.width:   bandMouse.pressed ? 2 : 1
        }
    }

    // ------------------------------------------------------------ action rail
    // 116 of 1280 in the artboard.
    FlyViewActionRail {
        id:                 actionRail
        anchors.left:       parent.left
        anchors.top:        toolbar.bottom
        anchors.bottom:     obstacleBand.top
        width:              ScreenTools.defaultFontPixelWidth * 8
        z:                  QGroundControl.zOrderTopMost
        visible:            !QGroundControl.videoManager.fullScreen
        guidedController:   guidedActionsController
    }

    // ------------------------------------------------------ instrument column
    // 340 of 1280 in the artboard.
    FlyViewInstrumentColumn {
        id:                 instrumentColumn
        anchors.right:      parent.right
        anchors.top:        toolbar.bottom
        anchors.bottom:     obstacleBand.top
        width:              ScreenTools.defaultFontPixelWidth * 23.5
        z:                  QGroundControl.zOrderTopMost
        visible:            !QGroundControl.videoManager.fullScreen
        vehicle:            _activeVehicle
        missionController:  _planController.missionController

        onSwapRequested:    _pipView._swapPip()
    }

    // Zone 1 of Main.dc.html. The stock toolbar is gone: its indicator row, its
    // tool buttons and the Flickable around them have no zone in the drawing,
    // and the three readouts worth keeping -- battery, GPS/RTK, EKF -- are what
    // the status bar draws, at the size the artboard gives them.
    //
    // Still called `toolbar` because every zone in this file anchors to it.
    FlyViewStatusBar {
        id:                         toolbar
        visible:                    !QGroundControl.videoManager.fullScreen
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
        anchors.bottom:         obstacleBand.top
        anchors.topMargin:      toolbar.height
        anchors.margins:        ScreenTools.defaultFontPixelWidth
        width:                  preferredWidth
        visible:                _showParameterFavoritesPanel && !QGroundControl.videoManager.fullScreen
        vehicle:                _activeVehicle
        panelVisible:           visible
        z:                      QGroundControl.zOrderTopMost
    }
}
