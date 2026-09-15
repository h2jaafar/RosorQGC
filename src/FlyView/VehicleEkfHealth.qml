import QtQuick

import QGroundControl

/// EKF health for one vehicle, as a single severity and a word for it.
///
/// Non-visual. Lifted out of CriticalStatusBar so the fly view's status bar can
/// show EKF health without re-deriving it: the rule is not obvious enough to
/// write twice. Two MAVLink sources describe the same filter and neither is
/// always present -- EKF_STATUS_REPORT carries variances, ESTIMATOR_STATUS
/// carries both ratios and "good estimate" flags -- so each subsystem is read
/// from whichever source answered, and a subsystem nothing answered for is left
/// out of the verdict rather than counted as healthy.
Item {
    id: root

    property var vehicle: null

    /// True once any subsystem has reported. Until then `severity` means nothing
    /// and callers should show the unknown state rather than "OK".
    readonly property bool known: _result.known

    /// 0 good, 1 warn, 2 bad. Only meaningful while `known`.
    readonly property int severity: _result.severity

    readonly property string text: known
                                    ? (severity === 2 ? qsTr("BAD")
                                        : severity === 1 ? qsTr("WARN")
                                        : qsTr("OK"))
                                    : qsTr("--")

    readonly property var _result: _worstSeverity()

    // Recomputed when either source updates. Facts are not individually bound
    // here because the verdict depends on which of ten of them are live.
    readonly property var _estimator: vehicle ? vehicle.estimatorStatus : null
    readonly property var _report:    vehicle ? vehicle.ekfStatusReport : null

    function _ratioAvailable(fact) {
        return fact && fact.rawValue !== undefined && !isNaN(fact.rawValue)
    }

    function _boolAvailable(fact) {
        return fact && fact.rawValue !== undefined
    }

    /// A variance ratio at or below 0.5 is healthy; past 1.0 the filter has
    /// diverged far enough that the estimate should not be trusted.
    function _ratioSeverity(ratio) {
        if (ratio <= 0.5) {
            return 0
        }
        return ratio <= 1.0 ? 1 : 2
    }

    /// Prefer the live ratio, fall back to the report's variance, and only then
    /// fall back to the coarse "is this estimate good" flag. -1 means no source
    /// answered for this subsystem.
    function _subsystemSeverityRatioOrGood(ratioFact, goodFact, fallbackRatioFact) {
        if (_ratioAvailable(ratioFact)) {
            return _ratioSeverity(ratioFact.rawValue)
        }
        if (_ratioAvailable(fallbackRatioFact)) {
            return _ratioSeverity(fallbackRatioFact.rawValue)
        }
        if (_boolAvailable(goodFact)) {
            return goodFact.rawValue ? 0 : 2
        }
        return -1
    }

    function _subsystemSeverityCompass(est, ekfReport) {
        if (!est && !ekfReport) {
            return -1
        }
        if (est && _ratioAvailable(est.magRatio)) {
            return _ratioSeverity(est.magRatio.rawValue)
        }
        if (ekfReport && _ratioAvailable(ekfReport.compassVariance)) {
            return _ratioSeverity(ekfReport.compassVariance.rawValue)
        }
        if (est && _boolAvailable(est.compassError)) {
            return est.compassError.rawValue ? 2 : 0
        }
        // NOTE: EstimatorStatusFactGroup.json spells this fact
        // "goodAttitudeEsimate". Until that is corrected this lookup is
        // undefined and the branch never fires -- kept as the original wrote it
        // so fixing the spelling is a deliberate change, not a silent one.
        if (est && _boolAvailable(est.goodAttitudeEstimate)) {
            return est.goodAttitudeEstimate.rawValue ? 0 : 2
        }
        return -1
    }

    function _estimatorAvailable() {
        return vehicle && vehicle.estimatorStatus && vehicle.estimatorStatus.telemetryAvailable
    }

    function _reportAvailable() {
        return vehicle && vehicle.ekfStatusReport && vehicle.ekfStatusReport.telemetryAvailable
    }

    function _worstSeverity() {
        if (!_estimatorAvailable() && !_reportAvailable()) {
            return { known: false, severity: -1 }
        }
        var est = vehicle.estimatorStatus
        var ekfReport = vehicle.ekfStatusReport

        var severities = [
            _subsystemSeverityRatioOrGood(est ? est.velRatio : null,
                                          est ? est.goodHorizVelEstimate : null,
                                          ekfReport ? ekfReport.velVariance : null),
            _subsystemSeverityRatioOrGood(est ? est.horizPosRatio : null,
                                          est ? est.goodHorizPosAbsEstimate : null,
                                          ekfReport ? ekfReport.posHorizVariance : null),
            _subsystemSeverityRatioOrGood(est ? est.vertPosRatio : null,
                                          est ? est.goodVertPosAbsEstimate : null,
                                          ekfReport ? ekfReport.posVertVariance : null),
            _subsystemSeverityCompass(est, ekfReport),
            _subsystemSeverityRatioOrGood(est ? est.haglRatio : null,
                                          est ? est.goodVertPosAGLEstimate : null,
                                          ekfReport ? ekfReport.terrainAltVariance : null)
        ]

        var worst = -1
        var known = false
        for (var i = 0; i < severities.length; i++) {
            if (severities[i] >= 0) {
                known = true
                worst = Math.max(worst, severities[i])
            }
        }
        return { known: known, severity: worst }
    }
}
