#include "CustomPlugin.h"

#include "AppSettings.h"
#include "SettingsManager.h"

#include <QtCore/QApplicationStatic>

Q_APPLICATION_STATIC(CustomPlugin, _customPluginInstance);

CustomPlugin::CustomPlugin(QObject *parent)
    : QGCCorePlugin(parent)
{
}

QGCCorePlugin *CustomPlugin::instance()
{
    return _customPluginInstance();
}

AppSettings *CustomPlugin::_appSettings() const
{
    return SettingsManager::instance()->appSettings();
}

const QVariantList &CustomPlugin::analyzePages()
{
    static const QVariantList emptyList;
    AppSettings *appSettings = _appSettings();
    const bool fieldModeEnabled = appSettings ? appSettings->fieldModeEnabled()->rawValue().toBool() : false;
    if (fieldModeEnabled) {
        return emptyList;
    }
    return QGCCorePlugin::analyzePages();
}
