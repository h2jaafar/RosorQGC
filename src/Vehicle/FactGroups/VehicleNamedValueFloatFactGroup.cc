#include "VehicleNamedValueFloatFactGroup.h"
#include "Vehicle.h"

#include <QtCore/QString>

VehicleNamedValueFloatFactGroup::VehicleNamedValueFloatFactGroup(QObject *parent)
    : FactGroup(0, parent)
{
}

void VehicleNamedValueFloatFactGroup::handleMessage(Vehicle *vehicle, const mavlink_message_t &message)
{
    Q_UNUSED(vehicle);

    if (message.msgid != MAVLINK_MSG_ID_NAMED_VALUE_FLOAT) {
        return;
    }

    mavlink_named_value_float_t msg{};
    mavlink_msg_named_value_float_decode(&message, &msg);

    // NAMED_VALUE_FLOAT::name is char[10], not guaranteed null terminated
    const int maxLen = static_cast<int>(sizeof(msg.name));
    int nameLen = 0;
    while (nameLen < maxLen && msg.name[nameLen] != '\0') {
        ++nameLen;
    }
    const QString name = QString::fromLatin1(msg.name, nameLen);
    if (name.isEmpty()) {
        return;
    }

    QVariantMap entry;
    entry[QStringLiteral("value")]       = msg.value;
    entry[QStringLiteral("timeBootMs")]  = msg.time_boot_ms;
    entry[QStringLiteral("updatedMs")]   = QDateTime::currentMSecsSinceEpoch();

    {
        QMutexLocker locker(&_valuesMutex);
        _values.insert(name, entry);
    }

    _setTelemetryAvailable(true);
    emit valuesChanged();
}
