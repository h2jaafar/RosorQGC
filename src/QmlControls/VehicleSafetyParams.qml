import QtQuick
import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

/// The safety policy the aircraft will actually follow, read off its own
/// parameters and said in operator words. Non-visual: the status drawer lays the
/// sentences out, the status bar borrows the link-lost one.
///
/// Everything here is ArduCopter's: RTL_ALT, FS_GCS_ENABLE / FS_GCS_TIMEOUT,
/// FENCE_*, BATT_LOW_VOLT / BATT_FS_LOW_ACT and friends, RADAR_STOP_MD from the
/// radar script. Every sentence is empty until its parameter is present, so a
/// vehicle without one says nothing rather than something made up. The
/// parameter access mirrors RadarAvoidParams: a ParameterEditorController built
/// only once a vehicle exists, refreshed when the parameter set changes.
Item {
    id: root

    property var vehicle: null

    readonly property var    _units: QGroundControl.unitsConversion
    readonly property string _vUnit: _units.appSettingsVerticalDistanceUnitsString
    readonly property string _hUnit: _units.appSettingsHorizontalDistanceUnitsString
    function _v(metres) { return Number(_units.metersToAppSettingsVerticalDistanceUnits(metres)) }
    function _h(metres) { return Number(_units.metersToAppSettingsHorizontalDistanceUnits(metres)) }

    // ------------------------------------------------------------ parameters

    property int _refresh: 0

    function _raw(fact) {
        if (!fact) {
            return undefined
        }
        var v = Number(fact.rawValue)
        return isNaN(v) ? undefined : v
    }

    function _fact(name) {
        root._refresh   // re-evaluate when the parameter set changes
        if (!_controller || !root.vehicle || !root.vehicle.parameterManager) {
            return null
        }
        // reportMissing false: an aircraft without a fence or a radar script has
        // none of these and must not raise a missing-parameter error for each.
        return _controller.getParameterFact(-1, name, false)
    }

    readonly property var _rtlAlt:      _fact("RTL_ALT")          // cm
    readonly property var _gcsEnable:   _fact("FS_GCS_ENABLE")
    readonly property var _gcsTimeout:  _fact("FS_GCS_TIMEOUT")   // s
    readonly property var _fenceEnable: _fact("FENCE_ENABLE")
    readonly property var _fenceType:   _fact("FENCE_TYPE")       // bitmask 1 alt max, 2 circle, 4 polygon, 8 alt min
    readonly property var _fenceAction: _fact("FENCE_ACTION")
    readonly property var _fenceAltMax: _fact("FENCE_ALT_MAX")    // m
    readonly property var _fenceRadius: _fact("FENCE_RADIUS")     // m
    readonly property var _battLowVolt: _fact("BATT_LOW_VOLT")    // V
    readonly property var _battLowMah:  _fact("BATT_LOW_MAH")
    readonly property var _battLowAct:  _fact("BATT_FS_LOW_ACT")
    readonly property var _battCrtVolt: _fact("BATT_CRT_VOLT")    // V
    readonly property var _battCrtAct:  _fact("BATT_FS_CRT_ACT")
    readonly property var _radarStop:   _fact("RADAR_STOP_MD")

    /// True once at least one policy parameter has arrived.
    readonly property bool known: _raw(_rtlAlt) !== undefined || _raw(_gcsEnable) !== undefined
                                  || _raw(_fenceEnable) !== undefined || _raw(_battLowAct) !== undefined

    // ------------------------------------------------------------- sentences

    /// "Return altitude 60 m", or "Returns at the current height" for RTL_ALT 0.
    readonly property string returnText: {
        var cm = _raw(_rtlAlt)
        if (cm === undefined) {
            return ""
        }
        if (cm <= 0) {
            return qsTr("Return: climbs no higher than it is")
        }
        return qsTr("Return altitude %1 %2").arg(_v(cm / 100).toFixed(0)).arg(_vUnit)
    }

    /// What the aircraft does when the controller goes quiet, in the words
    /// ArduCopter's FS_GCS_ENABLE values mean.
    function _linkLostVerb(code) {
        switch (code) {
        case 0:  return qsTr("nothing happens (failsafe off)")
        case 1:  return qsTr("returns home")
        case 2:  return qsTr("continues the mission, otherwise returns home")
        case 3:  return qsTr("returns home along its own track")
        case 4:  return qsTr("returns along its track, otherwise lands")
        case 5:  return qsTr("lands where it is")
        case 6:  return qsTr("flies to the landing sequence, otherwise returns home")
        case 7:  return qsTr("brakes, then lands")
        default: return qsTr("does what FS_GCS_ENABLE %1 says").arg(code)
        }
    }

    readonly property bool linkLostDanger: _raw(_gcsEnable) === 0

    /// Short form for the status bar: "returns home after 5 s".
    readonly property string linkLostShort: {
        var code = _raw(_gcsEnable)
        if (code === undefined) {
            return ""
        }
        var verb = _linkLostVerb(code)
        if (code === 0) {
            return verb
        }
        var timeout = _raw(_gcsTimeout)
        return timeout === undefined ? verb : qsTr("%1 after %2 s").arg(verb).arg(timeout.toFixed(0))
    }

    readonly property string linkLostText: linkLostShort === "" ? "" : qsTr("Link lost: %1").arg(linkLostShort)

    function _fenceVerb(code) {
        switch (code) {
        case 0:  return qsTr("report only")
        case 1:  return qsTr("returns home, otherwise lands")
        case 2:  return qsTr("lands")
        case 3:  return qsTr("returns along its track or home, otherwise lands")
        case 4:  return qsTr("brakes, then lands")
        case 5:  return qsTr("returns along its track, otherwise lands")
        default: return qsTr("FENCE_ACTION %1").arg(code)
        }
    }

    readonly property string fenceText: {
        var enabled = _raw(_fenceEnable)
        if (enabled === undefined) {
            return ""
        }
        if (enabled === 0) {
            return qsTr("Fence off")
        }
        var parts = [ qsTr("Fence on") ]
        var type = _raw(_fenceType)
        var altMax = _raw(_fenceAltMax)
        var radius = _raw(_fenceRadius)
        if (type !== undefined && (type & 1) && altMax !== undefined) {
            parts.push(qsTr("max %1 %2").arg(_v(altMax).toFixed(0)).arg(_vUnit))
        }
        if (type !== undefined && (type & 2) && radius !== undefined) {
            parts.push(qsTr("radius %1 %2").arg(_h(radius).toFixed(0)).arg(_hUnit))
        }
        if (type !== undefined && (type & 4)) {
            parts.push(qsTr("polygon"))
        }
        var action = _raw(_fenceAction)
        if (action !== undefined) {
            parts.push(qsTr("breach: %1").arg(_fenceVerb(action)))
        }
        return parts.join(" · ")
    }

    function _batteryVerb(code) {
        switch (code) {
        case 0:  return qsTr("nothing happens")
        case 1:  return qsTr("lands")
        case 2:  return qsTr("returns home")
        case 3:  return qsTr("returns home along its own track")
        case 4:  return qsTr("returns along its track, otherwise lands")
        case 5:  return qsTr("motors stop")
        case 6:  return qsTr("flies to the landing sequence, otherwise returns home")
        case 7:  return qsTr("brakes, then lands")
        default: return qsTr("BATT_FS_LOW_ACT %1").arg(code)
        }
    }

    readonly property bool batteryDanger: {
        var lowV = _raw(_battLowVolt)
        var lowMah = _raw(_battLowMah)
        var act = _raw(_battLowAct)
        if (act === undefined) {
            return false
        }
        return act === 0 || ((lowV === undefined || lowV <= 0) && (lowMah === undefined || lowMah <= 0))
    }

    readonly property string batteryText: {
        var act = _raw(_battLowAct)
        if (act === undefined) {
            return ""
        }
        var lowV = _raw(_battLowVolt)
        var lowMah = _raw(_battLowMah)
        if ((lowV === undefined || lowV <= 0) && (lowMah === undefined || lowMah <= 0)) {
            return qsTr("Low battery: no threshold set, so no failsafe")
        }
        var trigger = (lowV !== undefined && lowV > 0) ? qsTr("%1 V").arg(lowV.toFixed(1))
                                                       : qsTr("%1 mAh used").arg(lowMah.toFixed(0))
        var text = qsTr("Low battery at %1: %2").arg(trigger).arg(_batteryVerb(act))
        var crtV = _raw(_battCrtVolt)
        var crtAct = _raw(_battCrtAct)
        if (crtV !== undefined && crtV > 0 && crtAct !== undefined && crtAct !== 0) {
            text += qsTr(" · critical at %1 V: %2").arg(crtV.toFixed(1)).arg(_batteryVerb(crtAct))
        }
        return text
    }

    /// What a radar stop does, and the one consequence nobody tells the operator:
    /// a stop during Return parks the aircraft until someone acts.
    readonly property string obstacleStopText: {
        var mode = _raw(_radarStop)
        if (mode === undefined) {
            return ""
        }
        if (mode >= 2) {
            return qsTr("Obstacle ahead: offsets and continues")
        }
        var stop = mode === 1 ? qsTr("Obstacle ahead: brakes and holds") : qsTr("Obstacle ahead: holds position")
        return stop + qsTr(" · during Return it waits for you")
    }

    // ------------------------------------------------------------ controller

    property var _controller: controllerLoader.item

    Component {
        id: controllerComponent
        ParameterEditorController { }
    }

    /// Built only once a vehicle exists: FactPanelController snapshots the active
    /// vehicle in its constructor, and a controller built with the fly view would
    /// stay bound to the offline vehicle for the whole session.
    Loader {
        id:              controllerLoader
        active:          root.vehicle !== null
        sourceComponent: controllerComponent
    }

    Connections {
        target: root.vehicle ? root.vehicle.parameterManager : null
        ignoreUnknownSignals: true
        function onParametersReadyChanged() { root._refresh++ }
        function onFactAdded(componentId, fact) {
            if (fact && (fact.name.indexOf("RADAR_") === 0 || fact.name.indexOf("FENCE_") === 0
                         || fact.name.indexOf("BATT_") === 0 || fact.name.indexOf("FS_") === 0
                         || fact.name === "RTL_ALT")) {
                root._refresh++
            }
        }
    }

    onVehicleChanged: root._refresh++
}
