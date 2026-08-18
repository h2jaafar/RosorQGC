import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

Rectangle {
    id:                     root
    color:                  qgcPal.window
    border.color:           qgcPal.groupBorder
    radius:                 ScreenTools.defaultBorderRadius
    transformOrigin:        Item.TopRight
    scale:                  panelScale
    implicitWidth:          preferredWidth

    property var    vehicle:            null
    property bool   panelVisible:       false
    property string searchText:         ""
    property string selectedParamName:  ""
    property var    activeVehicle:      vehicle ? vehicle : QGroundControl.multiVehicleManager.activeVehicle
    property int    _paramRefreshCounter: 0
    property string selectedParam:      ""
    // Bound so the edit pane's fact refreshes when parameters load / vehicle
    // swaps. Reading _paramRefreshCounter forces re-evaluation on each bump.
    property var    selectedFact:       {
        _paramRefreshCounter
        if (!selectedParam || !_controller || !activeVehicle || !activeVehicle.parameterManager) {
            return null
        }
        return _controller.getParameterFact(-1, selectedParam, false)
    }
    property bool   editOpen:           false

    property var _appSettings:          QGroundControl.settingsManager.appSettings
    property var _controller:           controllerLoader.item
    property var _favoritesModel:       favoritesModel

    property real _uiScale: {
        var base = ScreenTools.platformFontPointSize
        if (base <= 0) {
            return 1.0
        }
        var appSize = _appSettings.appFontPointSize.value
        var activeSize = appSize > 0 ? appSize : ScreenTools.defaultFontPointSize
        return activeSize / base
    }
    property real panelScale: {
        var scaled = 1.0 + (_uiScale - 1.0) * 0.6
        return Math.max(1.0, Math.min(1.35, scaled))
    }
    property real minPanelWidth: ScreenTools.defaultFontPixelWidth * 32
    property real maxPanelWidth: ScreenTools.defaultFontPixelWidth * 42
    property real preferredWidth: {
        var available = parent ? parent.width - (ScreenTools.defaultFontPixelWidth * 2) : maxPanelWidth
        var target = Math.min(ScreenTools.defaultFontPixelWidth * 34, available)
        return Math.max(minPanelWidth, Math.min(maxPanelWidth, target))
    }
    property real vGap: ScreenTools.defaultFontPixelHeight * 0.6
    property real pad:  ScreenTools.defaultFontPixelHeight * 0.8

    QGCPalette { id: qgcPal }

    Component {
        id: parameterControllerComponent

        ParameterEditorController { }
    }

    Loader {
        id: controllerLoader
        sourceComponent: parameterControllerComponent
    }

    ListModel {
        id: favoritesModel
    }

    function _splitList(rawValue) {
        if (!rawValue || rawValue.trim() === "") {
            return []
        }
        var parts = rawValue.split(",")
        var result = []
        for (var i = 0; i < parts.length; i++) {
            var item = parts[i].trim()
            if (item !== "" && result.indexOf(item) === -1) {
                result.push(item)
            }
        }
        return result
    }

    function _joinList(list) {
        return list.join(",")
    }

    function _favoritesList() {
        return _splitList(_appSettings.parameterFavorites.value)
    }

    function _defaultsForVehicle() {
        if (!vehicle) {
            return []
        }
        if (vehicle.fixedWing) {
            return _splitList(_appSettings.parameterFavoritesPlaneDefaults.value)
        } else if (vehicle.rover) {
            return _splitList(_appSettings.parameterFavoritesRoverDefaults.value)
        }
        return _splitList(_appSettings.parameterFavoritesCopterDefaults.value)
    }

    function _seedDefaultsIfNeeded() {
        var current = _favoritesList()
        if (current.length !== 0) {
            return
        }
        var defaults = _defaultsForVehicle()
        if (defaults.length !== 0) {
            _appSettings.parameterFavorites.value = _joinList(defaults)
        }
    }

    function _refreshModel() {
        favoritesModel.clear()
        var favorites = _favoritesList()
        var filter = searchText.trim().toUpperCase()
        for (var i = 0; i < favorites.length; i++) {
            var name = favorites[i]
            if (filter !== "" && name.toUpperCase().indexOf(filter) === -1) {
                continue
            }
            favoritesModel.append({ paramName: name })
        }
    }

    function _addFavorite(name) {
        var trimmed = name.trim().toUpperCase()
        if (trimmed === "") {
            return
        }
        // Don't gate on the parameter actually existing on the current
        // vehicle — user may add favorites while disconnected, or the
        // parameter may load later. The delegate renders "Missing" if the
        // Fact isn't available yet.
        var favorites = _favoritesList()
        if (favorites.indexOf(trimmed) === -1) {
            favorites.push(trimmed)
            _appSettings.parameterFavorites.value = _joinList(favorites)
        }
    }

    function _removeFavorite(name) {
        var favorites = _favoritesList()
        var index = favorites.indexOf(name)
        if (index !== -1) {
            favorites.splice(index, 1)
            _appSettings.parameterFavorites.value = _joinList(favorites)
        }
    }

    onVehicleChanged: _seedDefaultsIfNeeded()
    onSearchTextChanged: _refreshModel()
    onPanelVisibleChanged: if (panelVisible) { _seedDefaultsIfNeeded(); _refreshModel() }
    onActiveVehicleChanged: {
        controllerLoader.active = false
        controllerLoader.active = true
        _paramRefreshCounter++
    }

    Connections {
        target: _appSettings.parameterFavorites
        function onValueChanged() { _refreshModel() }
    }

    Connections {
        target: activeVehicle ? activeVehicle.parameterManager : null
        function onParametersReadyChanged() { _paramRefreshCounter++ }
        function onFactAdded() { _paramRefreshCounter++ }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: pad
        spacing: vGap

        QGCLabel {
            text: qsTr("Parameter Favorites")
            font.pointSize: ScreenTools.largeFontPointSize
            Layout.bottomMargin: vGap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: vGap

            QGCTextField {
                id: addFavoriteField
                Layout.fillWidth: true
                placeholderText: qsTr("Add parameter (e.g. BATT_LOW_VOLT)")
                onAccepted: {
                    _addFavorite(text)
                    text = ""
                }
            }

            QGCButton {
                text: qsTr("Add")
                onClicked: {
                    _addFavorite(addFavoriteField.text)
                    addFavoriteField.text = ""
                }
            }
        }

        QGCTextField {
            Layout.fillWidth: true
            Layout.topMargin: vGap
            placeholderText: qsTr("Search favorites")
            text: searchText
            onTextChanged: searchText = text
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: vGap

            ColumnLayout {
                anchors.fill: parent
                spacing: vGap

                QGCLabel {
                    Layout.fillWidth: true
                    text: vehicle ? qsTr("No favorites yet") : qsTr("No vehicle connected")
                    visible: favoritesModel.count === 0
                }

                ListView {
                    id: favoritesListView
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: favoritesModel
                    clip: true
                    spacing: vGap

                    delegate: Rectangle {
                        width: favoritesListView.width
                        implicitHeight: ScreenTools.defaultFontPixelHeight * 2.2
                        color: qgcPal.windowShade
                        radius: ScreenTools.defaultBorderRadius
                        border.color: qgcPal.groupBorder

                        property string paramName: model.paramName
                        property int _refreshToken: _paramRefreshCounter
                        property var paramFact: {
                            _refreshToken
                            if (!_controller || !activeVehicle || !activeVehicle.parameterManager) {
                                return null
                            }
                            return _controller.getParameterFact(-1, paramName, false)
                        }
                        property bool parametersReady: activeVehicle && activeVehicle.parameterManager ? activeVehicle.parameterManager.parametersReady : false
                        property string valueText: {
                            if (paramFact) {
                                var base = paramFact.valueString
                                if (!base || base === "") {
                                    base = "" + paramFact.value
                                }
                                var units = paramFact.units ? (" " + paramFact.units) : ""
                                return base + units
                            }
                            if (activeVehicle && parametersReady) {
                                return qsTr("Missing")
                            }
                            return qsTr("--")
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: vGap
                            spacing: vGap

                            QGCLabel {
                                Layout.fillWidth: true
                                text: paramName
                                elide: Text.ElideRight
                            }

                            QGCLabel {
                                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 10
                                text: valueText
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight
                            }

                            QGCButton {
                                id: starButton
                                Layout.preferredWidth: ScreenTools.defaultFontPixelWidth * 4
                                text: qsTr("*")
                                onClicked: _removeFavorite(paramName)
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: (mouse) => {
                                if (mouse.x >= starButton.x && mouse.x <= (starButton.x + starButton.width)) {
                                    return
                                }
                                // selectedFact is a bound property that re-reads on selectedParam change,
                                // so we only need to set the name here.
                                selectedParam = paramName
                                editOpen = true
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: editPane
            Layout.fillWidth: true
            Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 10
            Layout.preferredHeight: Math.max(ScreenTools.defaultFontPixelHeight * 12, root.height * 0.35)
            color: qgcPal.windowShade
            radius: ScreenTools.defaultBorderRadius
            border.color: qgcPal.groupBorder
            visible: editOpen

            property bool hasFact: selectedFact !== null
            property bool hasEnum: hasFact && selectedFact.enumStrings && selectedFact.enumStrings.length > 0
            property bool isBool: hasFact && selectedFact.typeIsBool

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: pad
                spacing: vGap

                RowLayout {
                    Layout.fillWidth: true

                    QGCLabel {
                        Layout.fillWidth: true
                        text: selectedParam
                        elide: Text.ElideRight
                    }

                    QGCButton {
                        text: qsTr("Close")
                        onClicked: editOpen = false
                    }
                }

                QGCLabel {
                    Layout.fillWidth: true
                    text: selectedFact ? selectedFact.shortDescription : qsTr("Unavailable")
                    wrapMode: Text.WordWrap
                }

                Loader {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    sourceComponent: editPane.hasFact ? (hasEnum ? enumEditorComponent : (isBool ? boolEditorComponent : valueEditorComponent)) : missingEditorComponent
                }
            }

            Component {
                id: valueEditorComponent

                FactTextField {
                    Layout.fillWidth: true
                    Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 2.2
                    fact: selectedFact
                    enabled: selectedFact
                }
            }

            Component {
                id: enumEditorComponent

                FactComboBox {
                    Layout.fillWidth: true
                    Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 2.2
                    fact: selectedFact
                }
            }

            Component {
                id: boolEditorComponent

                FactCheckBox {
                    Layout.fillWidth: true
                    Layout.minimumHeight: ScreenTools.defaultFontPixelHeight * 2.2
                    fact: selectedFact
                }
            }

            Component {
                id: missingEditorComponent

                QGCLabel {
                    text: qsTr("No parameter data available")
                }
            }
        }
    }
}
