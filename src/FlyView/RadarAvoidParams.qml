import QtQuick

import QGroundControl
import QGroundControl.Controls
import QGroundControl.FactControls

/// Live RADAR_* avoidance parameters from u300-avoid.lua, read off the vehicle.
///
/// These are the values the script actually uses to decide when to stop, so
/// they are the only honest source for a trigger distance -- ObstacleHUD reads
/// exactly the same set (see obstacle_hud.py live_trigger_info()). Anything
/// picked locally would be a guess that disagrees with the aircraft.
///
/// Every reading is NaN / undefined until the parameter is actually present:
/// a vehicle not running the script has none of these, and drawing a trigger
/// at 0 m would be worse than drawing nothing. Unlike the O_C*/U3M sensor
/// values these do not go stale -- a parameter stays true until the vehicle
/// reboots or someone changes it -- so there is no timeout here.
Item {
    id: root

    property var vehicle: null

    /// Forward trigger distance in metres, NaN when unknown.
    readonly property real fwdTrigM:    _num(_fwdFact) === undefined
                                            ? (_num(_legacyFact) === undefined ? NaN : _num(_legacyFact))
                                            : _num(_fwdFact)
    /// Downward radar floor (height AGL) in metres, NaN when unknown.
    readonly property real dwnFloorM:   _num(_dwnFact) === undefined ? NaN : _num(_dwnFact)
    /// Distance at which the script considers the obstacle cleared again.
    readonly property real clearM:      isNaN(fwdTrigM) ? NaN : fwdTrigM + _clearMarginM
    /// true / false when known, undefined when the parameter is absent.
    readonly property var  avoidEnabled: _num(_enFact) === undefined
                                            ? undefined
                                            : (_num(_enFact) !== 0)
    /// LOITER / BRAKE / AUTO-OFS. Defaults to LOITER, which is the script's own
    /// default, and mirrors the vehicle rather than guessing locally.
    readonly property string stopModeName: {
        var v = _num(_stopFact)
        if (v === undefined) {
            return "LOITER"
        }
        var i = Math.round(v)
        return i === 1 ? "BRAKE" : (i >= 2 ? "AUTO-OFS" : "LOITER")
    }
    /// AUTO-OFS climbs over the obstacle and keeps flying -- it does not stop.
    readonly property bool stopsOnTrigger: stopModeName !== "AUTO-OFS"
    readonly property bool haveTrigger:    !isNaN(fwdTrigM) && fwdTrigM > 0

    /// Slung-payload ignore band (v1.5+): centre range is the tether length,
    /// 0 means off. A tethered load holds a constant range at any swing angle,
    /// so range alone identifies it.
    readonly property real ignoreRangeM:     _num(_ignMFact) === undefined ? NaN : _num(_ignMFact)
    readonly property real ignoreHalfWidthM: _num(_ignWFact) === undefined ? 0 : Math.max(0, _num(_ignWFact))
    readonly property bool haveIgnoreBand:   !isNaN(ignoreRangeM) && ignoreRangeM > 0

    // Must match u300-avoid.lua's AVOID_CLEAR_MARGIN_M.
    readonly property real _clearMarginM: 3.0

    property int _refresh: 0

    function _num(fact) {
        return fact ? fact.value : undefined
    }

    function _fact(name) {
        root._refresh   // re-evaluate when the parameter set changes
        if (!_controller || !root.vehicle || !root.vehicle.parameterManager) {
            return null
        }
        // reportMissing false: a vehicle without the avoidance script has none
        // of these and must not raise a missing-parameter error for each one.
        return _controller.getParameterFact(-1, name, false)
    }

    readonly property var _fwdFact:    _fact("RADAR_FWD_M")    // v1.4+
    readonly property var _legacyFact: _fact("RADAR_TRIG_M")   // pre-v1.4, both radars shared it
    readonly property var _dwnFact:    _fact("RADAR_DWN_M")    // v1.4+
    readonly property var _enFact:     _fact("RADAR_AVD_EN")
    readonly property var _stopFact:   _fact("RADAR_STOP_MD")
    readonly property var _ignMFact:   _fact("RADAR_IGN_M")     // v1.5+
    readonly property var _ignWFact:   _fact("RADAR_IGN_W")     // v1.5+

    property var _controller: controllerLoader.item

    Component {
        id: controllerComponent
        ParameterEditorController { }
    }

    /// Built only once a vehicle exists -- not eagerly with the fly view.
    ///
    /// FactPanelController snapshots MultiVehicleManager::activeVehicle() in its
    /// constructor and never updates it, falling back to the offline editing
    /// vehicle when nothing is connected. The fly view is created long before
    /// any link comes up, so a controller built eagerly stays bound to that
    /// offline vehicle for the whole session and every getParameterFact() call
    /// searches an empty parameter set. That is why the trigger read as unknown
    /// on the bench 2026-09-14 while the Parameter editor listed
    /// RADAR_FWD_M = 25.0 on the same vehicle -- the editor's own controller is
    /// built after you connect, so it snapshots the real one.
    Loader {
        id:              controllerLoader
        active:          root.vehicle !== null
        sourceComponent: controllerComponent
    }

    Connections {
        target: root.vehicle ? root.vehicle.parameterManager : null
        ignoreUnknownSignals: true

        function onParametersReadyChanged() { root._refresh++ }

        /// The RADAR_* set is not firmware-owned: u300-avoid.lua registers it at
        /// run time, so the parameters routinely appear *after* the initial
        /// download has finished and parametersReady has already fired. Without
        /// this the fact bindings below keep the null they resolved to while the
        /// script's table was still empty, and the trigger reads as unknown even
        /// though the vehicle is reporting it -- verified on the bench
        /// 2026-09-14, where the Parameter editor listed RADAR_FWD_M = 25.0
        /// while the fly view still showed "TRIG --".
        function onFactAdded(componentId, fact) {
            if (fact && fact.name.indexOf("RADAR_") === 0) {
                root._refresh++
            }
        }
    }

    onVehicleChanged: root._refresh++
}
