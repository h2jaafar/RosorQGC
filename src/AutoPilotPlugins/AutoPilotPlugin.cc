#include "AutoPilotPlugin.h"
#include "FirmwarePlugin.h"
#include "QGCApplication.h"
#include "QGCLoggingCategory.h"
#include "Vehicle.h"
#include "VehicleComponent.h"

QGC_LOGGING_CATEGORY(AutoPilotPluginLog, "AutoPilotPlugins.AutoPilotPlugin");

AutoPilotPlugin::AutoPilotPlugin(Vehicle *vehicle, QObject *parent)
    : QObject(parent)
    , _vehicle(vehicle)
    , _firmwarePlugin(vehicle->firmwarePlugin())
{
    qCDebug(AutoPilotPluginLog) << this;
}

AutoPilotPlugin::~AutoPilotPlugin()
{
    qCDebug(AutoPilotPluginLog) << this;
}

void AutoPilotPlugin::_recalcSetupComplete()
{
    bool newSetupComplete = true;

    for (const QVariant &componentVariant : vehicleComponents()) {
        const VehicleComponent *const component = qobject_cast<const VehicleComponent*>(qvariant_cast<const QObject*>(componentVariant));
        if (component) {
            if (!component->setupComplete()) {
                newSetupComplete = false;
                break;
            }
        } else {
            qCWarning(AutoPilotPluginLog) << "Incorrectly typed VehicleComponent";
        }
    }

    if (_setupComplete != newSetupComplete) {
        _setupComplete = newSetupComplete;
        emit setupCompleteChanged();
    }
}

void AutoPilotPlugin::parametersReadyPreChecks()
{
    _recalcSetupComplete();

    // Connect signals in order to keep setupComplete up to date
    for (QVariant componentVariant : vehicleComponents()) {
        VehicleComponent *const component = qobject_cast<VehicleComponent*>(qvariant_cast<QObject*>(componentVariant));
        if (component) {
            (void) connect(component, &VehicleComponent::setupCompleteChanged, this, &AutoPilotPlugin::_recalcSetupComplete);
        } else {
            qCWarning(AutoPilotPluginLog) << "Incorrectly typed VehicleComponent";
        }
    }

    if (!_setupComplete) {
        // Tell, do not hijack. Upstream Stable_V5.1 does the same; the older base this
        // fork carries jumped the operator into Vehicle Configuration on every connect
        // to an aircraft with any unfinished setup component, over the map they came for.
        qgcApp()->showAppMessage(tr("Configuration tasks remain before this vehicle is ready to fly. See Vehicle Configuration for details."));
    }
}

VehicleComponent *AutoPilotPlugin::findKnownVehicleComponent(KnownVehicleComponent knownVehicleComponent)
{
    if (knownVehicleComponent != UnknownVehicleComponent) {
        for (const QVariant &componentVariant: vehicleComponents()) {
            VehicleComponent *const component = qobject_cast<VehicleComponent*>(qvariant_cast<QObject *>(componentVariant));
            if (component && (component->KnownVehicleComponent() == knownVehicleComponent)) {
                return component;
            }
        }
    }

    return nullptr;
}
