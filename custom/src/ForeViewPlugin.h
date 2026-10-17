#pragma once

#include <QtQml/QQmlAbstractUrlInterceptor>

#include "QGCCorePlugin.h"

class ForeViewCamera;
class ForeViewMode;
class QQmlApplicationEngine;

/// Redirects qrc:/X to qrc:/Custom/X when ForeView ships its own version of that
/// resource (logos, window icon, and the customer-mode QML overrides).
/// Everything else resolves to the stock QGC file.
class ForeViewOverrideInterceptor : public QQmlAbstractUrlInterceptor
{
public:
    QUrl intercept(const QUrl &url, QQmlAbstractUrlInterceptor::DataType type) final;
};

/// ForeView core plugin.
///
/// ForeView starts in customer mode: a simplified Fly view, a view menu without Analyze and
/// vehicle setup, and only the settings pages a customer needs. The full QGroundControl UI is
/// Debug Mode, unlocked with the company password (ForeViewMode). QGC's own "advanced UI"
/// switch is kept on in both modes so the Plan view offers every option.
class ForeViewPlugin : public QGCCorePlugin
{
    Q_OBJECT

public:
    explicit ForeViewPlugin(QObject *parent = nullptr);

    static QGCCorePlugin *instance();

    void init() final;
    void cleanup() final;
    QQmlApplicationEngine *createQmlApplicationEngine(QObject *parent) final;
    QString stableDownloadLocation() const final { return QString(); }
    void paletteOverride(const QString &colorName, QGCPalette::PaletteColorInfo_t &colorInfo) final;
    void adjustSettingMetaData(const QString &settingsGroup, FactMetaData &metaData, bool &userVisible) final;

private:
    void _createObjects();
    void _keepAdvancedUI();

    QQmlApplicationEngine *_qmlEngine = nullptr;
    ForeViewOverrideInterceptor *_interceptor = nullptr;
    ForeViewMode *_mode = nullptr;
    ForeViewCamera *_camera = nullptr;
};
