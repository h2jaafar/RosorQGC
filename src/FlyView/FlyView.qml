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

    function _applyModernHudFieldDefault() {
        if (_fieldModeEnabled && !_appSettings.modernHudFieldDefaultApplied.value) {
            _appSettings.modernHudEnabled.value = true
            _appSettings.modernHudFieldDefaultApplied.value = true
        }
    }

    Component.onCompleted: _applyModernHudFieldDefault()
    on_FieldModeEnabledChanged: _applyModernHudFieldDefault()

    function _calcCenterViewPort() {
        var newToolInset = Qt.rect(0, 0, width, height)
        toolstrip.adjustToolInset(newToolInset)
    }

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
            anchors.topMargin:      toolbar.height + _toolsMargin
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

        // Tab to swap the primary flight display with the map. Hidden when a video
        // stream is present, since PipView is then swapping map and video instead.
        QGCButton {
            id:                     pfdSwapTab
            anchors.top:            parent.top
            anchors.right:          parent.right
            anchors.topMargin:      toolbar.height + _toolsMargin
            anchors.rightMargin:    _toolsMargin
            z:                      QGroundControl.zOrderWidgets
            visible:                !QGroundControl.videoManager.hasVideo &&
                                        QGroundControl.corePlugin.options.flyView.showInstrumentPanel
            text:                   _mainWindowIsMap ? qsTr("PFD") : qsTr("Map")
            onClicked:              _pipView._swapPip()
        }

        FlyViewWidgetLayer {
            id:                     widgetLayer
            anchors.top:            parent.top
            anchors.bottom:         parent.bottom
            anchors.left:           parent.left
            anchors.right:          guidedValueSlider.visible ? guidedValueSlider.left : parent.right
            anchors.margins:        _widgetMargin
            anchors.topMargin:      toolbar.height + _widgetMargin
            bottomRowReservedHeight: (criticalStatusBar ? criticalStatusBar.height : 0) + _widgetMargin
            z:                      _fullItemZorder + 2 // we need to add one extra layer for map 3d viewer (normally was 1)
            parentToolInsets:       _toolInsets
            mapControl:             _mapControl
            visible:                !QGroundControl.videoManager.fullScreen
            isViewer3DOpen:         viewer3DWindow.isOpen
            pfdIsMainPane:          !_mainWindowIsMap && !QGroundControl.videoManager.hasVideo
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

    ModernHud {
        id:                 modernHud
        anchors.top:        toolbar.bottom
        anchors.bottom:     criticalStatusBar.top
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.margins:    ScreenTools.defaultFontPixelHeight * 0.8
        z:                  QGroundControl.zOrderWidgets
        vehicle:            _activeVehicle
        visible:            _appSettings.modernHudEnabled.value && !QGroundControl.videoManager.fullScreen
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

    CriticalStatusBar {
        id:                 criticalStatusBar
        anchors.left:       parent.left
        anchors.right:      parent.right
        anchors.bottom:     parent.bottom
        z:                  QGroundControl.zOrderTopMost
        vehicle:            _activeVehicle
        fieldModeEnabled:   _fieldModeEnabled
    }

    // Obstacle band: a full-width strip along the bottom, above the critical
    // status bar. The closest-obstacle distance is the largest number on the
    // screen because it is the one that decides whether to stop.
    //
    // No "inside trigger" state is drawn. The mockup had one, but nothing in
    // the firmware or the named-value stream tells us the avoidance trigger
    // distance, and a made-up threshold on a safety readout is worse than none.
    Rectangle {
        id:                     obstacleBand
        anchors.left:           parent.left
        anchors.right:          parent.right
        anchors.bottom:         criticalStatusBar.top
        height:                 ScreenTools.defaultFontPixelHeight * 7.5
        z:                      QGroundControl.zOrderTopMost
        color:                  "#20242a"
        opacity:                0.94

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
        readonly property bool _insideTrigger: radarParams.haveTrigger &&
                                               radarParams.avoidEnabled !== false &&
                                               !isNaN(obstacleBand._closest) &&
                                               obstacleBand._closest <= radarParams.fwdTrigM

        readonly property string _triggerText: {
            if (radarParams.avoidEnabled === false) {
                return qsTr("AVOID OFF")
            }
            if (!radarParams.haveTrigger) {
                return qsTr("TRIG —")
            }
            return qsTr("TRIG %1 m · %2")
                        .arg(radarParams.fwdTrigM.toFixed(1))
                        .arg(radarParams.stopModeName)
        }

        // ------------------------------------------------ closest-obstacle cell
        Rectangle {
            id:             closestCell
            anchors.left:   parent.left
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            width:          ScreenTools.defaultFontPixelWidth * 22
            color:          Qt.rgba(1, 1, 1, 0.05)

            Column {
                anchors.fill:       parent
                anchors.margins:    ScreenTools.defaultFontPixelWidth * 0.7
                spacing:            0

                QGCLabel {
                    text:           qsTr("CLOSEST OBSTACLE")
                    font.pointSize: ScreenTools.smallFontPointSize
                    color:          "#8d959d"
                }

                // RowLayout, not Row: the unit sits on the big number's
                // baseline, and anchors are not to be mixed with a positioner.
                RowLayout {
                    spacing: ScreenTools.defaultFontPixelWidth * 0.4

                    QGCLabel {
                        Layout.alignment:   Qt.AlignBaseline
                        text:               isNaN(obstacleBand._closest)
                                                ? "—"
                                                : obstacleBand._closest.toFixed(1)
                        font.pointSize:     ScreenTools.largeFontPointSize * 1.9
                        font.bold:          true
                        color:              obstacleBand._insideTrigger ? "#e05252" : "#e8eaed"
                    }

                    QGCLabel {
                        Layout.alignment:   Qt.AlignBaseline
                        text:               qsTr("m")
                        font.pointSize:     ScreenTools.defaultFontPointSize
                        color:              "#8d959d"
                        visible:            !isNaN(obstacleBand._closest)
                    }
                }

                QGCLabel {
                    text:           isNaN(obstacleBand._radarAlt)
                                        ? qsTr("RDR —")
                                        : qsTr("RDR %1 m").arg(obstacleBand._radarAlt.toFixed(1))
                    font.pointSize: ScreenTools.smallFontPointSize
                    color:          "#8d959d"
                }

                QGCLabel {
                    text:           obstacleBand._triggerText
                    font.pointSize: ScreenTools.smallFontPointSize
                    color:          radarParams.avoidEnabled === false ? "#eecc44"
                                        : (obstacleBand._insideTrigger ? "#e05252" : "#8d959d")
                }
            }
        }

        // ------------------------------------------------------ profile itself
        Item {
            anchors.left:   closestCell.right
            anchors.right:  parent.right
            anchors.top:    parent.top
            anchors.bottom: parent.bottom

            ObstacleTerrainProfile {
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

    FlyViewToolBar {
        id:                 toolbar
        guidedValueSlider:  _guidedValueSlider
        utmspSliderTrigger: utmspSendActTrigger
        visible:            !QGroundControl.videoManager.fullScreen
        parameterFavoritesVisible: _showParameterFavoritesPanel
        onToggleParameterFavorites: _showParameterFavoritesPanel = !_showParameterFavoritesPanel
        onShowMissionQuickVerify: openMissionQuickVerify()
        onShowObstacleProfile: openObstacleProfile()
        onReviewVehicleMessages: dropMainStatusIndicatorTool()
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
        anchors.bottom:         criticalStatusBar.top
        anchors.topMargin:      toolbar.height
        anchors.margins:        ScreenTools.defaultFontPixelWidth
        width:                  preferredWidth
        visible:                _showParameterFavoritesPanel && !QGroundControl.videoManager.fullScreen
        vehicle:                _activeVehicle
        panelVisible:           visible
        z:                      QGroundControl.zOrderTopMost
    }
}
