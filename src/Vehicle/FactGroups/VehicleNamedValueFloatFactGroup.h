#pragma once

#include "FactGroup.h"

#include <QtCore/QDateTime>
#include <QtCore/QHash>
#include <QtCore/QMutex>
#include <QtCore/QMutexLocker>
#include <QtCore/QVariantMap>

class VehicleNamedValueFloatFactGroup : public FactGroup
{
    Q_OBJECT
    Q_PROPERTY(QVariantMap values READ values NOTIFY valuesChanged)

public:
    explicit VehicleNamedValueFloatFactGroup(QObject *parent = nullptr);

    QVariantMap values() const {
        QMutexLocker locker(&_valuesMutex);
        return _values;
    }

    Q_INVOKABLE QVariant get(const QString &name) const {
        QMutexLocker locker(&_valuesMutex);
        return _values.value(name);
    }

    void handleMessage(Vehicle *vehicle, const mavlink_message_t &message) final;

signals:
    void valuesChanged();

private:
    QVariantMap _values;
    mutable QMutex _valuesMutex;
};
