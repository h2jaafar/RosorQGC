#include "VehicleEkfStatusReportFactGroup.h"
#include "Vehicle.h"

#include <QtCore/QDateTime>

VehicleEkfStatusReportFactGroup::VehicleEkfStatusReportFactGroup(QObject *parent)
    : FactGroup(500, QStringLiteral(":/json/Vehicle/EkfStatusReportFactGroup.json"), parent)
{
    _addFact(&_flagsFact);
    _addFact(&_velVarianceFact);
    _addFact(&_posHorizVarianceFact);
    _addFact(&_posVertVarianceFact);
    _addFact(&_compassVarianceFact);
    _addFact(&_terrainAltVarianceFact);
}

void VehicleEkfStatusReportFactGroup::handleMessage(Vehicle *vehicle, const mavlink_message_t &message)
{
    Q_UNUSED(vehicle);

    if (message.msgid != MAVLINK_MSG_ID_EKF_STATUS_REPORT) {
        return;
    }

    mavlink_ekf_status_report_t report{};
    mavlink_msg_ekf_status_report_decode(&message, &report);

    flags()->setRawValue(report.flags);
    velVariance()->setRawValue(report.velocity_variance);
    posHorizVariance()->setRawValue(report.pos_horiz_variance);
    posVertVariance()->setRawValue(report.pos_vert_variance);
    compassVariance()->setRawValue(report.compass_variance);
    terrainAltVariance()->setRawValue(report.terrain_alt_variance);

    _setTelemetryAvailable(true);

    static qint64 lastLogMs = 0;
    const qint64 nowMs = QDateTime::currentMSecsSinceEpoch();
    if ((nowMs - lastLogMs) > 5000) {
        lastLogMs = nowMs;
        qCDebug(VehicleLog) << "EKF status report variances"
                            << "vel" << report.velocity_variance
                            << "posH" << report.pos_horiz_variance
                            << "posV" << report.pos_vert_variance
                            << "compass" << report.compass_variance
                            << "terrain" << report.terrain_alt_variance;
    }
}
