#pragma once

#include "QGCCorePlugin.h"

class AppSettings;

class CustomPlugin : public QGCCorePlugin
{
    Q_OBJECT

public:
    explicit CustomPlugin(QObject *parent = nullptr);
    ~CustomPlugin() override = default;

    static QGCCorePlugin *instance();

    const QVariantList &analyzePages() override;

private:
    AppSettings *_appSettings() const;
};
