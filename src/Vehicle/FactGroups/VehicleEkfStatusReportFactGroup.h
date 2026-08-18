#pragma once

#include "FactGroup.h"

class VehicleEkfStatusReportFactGroup : public FactGroup
{
    Q_OBJECT
    Q_PROPERTY(Fact *flags               READ flags               CONSTANT)
    Q_PROPERTY(Fact *velVariance         READ velVariance         CONSTANT)
    Q_PROPERTY(Fact *posHorizVariance    READ posHorizVariance    CONSTANT)
    Q_PROPERTY(Fact *posVertVariance     READ posVertVariance     CONSTANT)
    Q_PROPERTY(Fact *compassVariance     READ compassVariance     CONSTANT)
    Q_PROPERTY(Fact *terrainAltVariance  READ terrainAltVariance  CONSTANT)

public:
    explicit VehicleEkfStatusReportFactGroup(QObject *parent = nullptr);

    Fact *flags() { return &_flagsFact; }
    Fact *velVariance() { return &_velVarianceFact; }
    Fact *posHorizVariance() { return &_posHorizVarianceFact; }
    Fact *posVertVariance() { return &_posVertVarianceFact; }
    Fact *compassVariance() { return &_compassVarianceFact; }
    Fact *terrainAltVariance() { return &_terrainAltVarianceFact; }

    void handleMessage(Vehicle *vehicle, const mavlink_message_t &message) final;

private:
    Fact _flagsFact = Fact(0, QStringLiteral("flags"), FactMetaData::valueTypeUint16);
    Fact _velVarianceFact = Fact(0, QStringLiteral("velVariance"), FactMetaData::valueTypeFloat);
    Fact _posHorizVarianceFact = Fact(0, QStringLiteral("posHorizVariance"), FactMetaData::valueTypeFloat);
    Fact _posVertVarianceFact = Fact(0, QStringLiteral("posVertVariance"), FactMetaData::valueTypeFloat);
    Fact _compassVarianceFact = Fact(0, QStringLiteral("compassVariance"), FactMetaData::valueTypeFloat);
    Fact _terrainAltVarianceFact = Fact(0, QStringLiteral("terrainAltVariance"), FactMetaData::valueTypeFloat);
};
