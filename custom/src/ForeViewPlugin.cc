#include "ForeViewPlugin.h"

#include "AppSettings.h"
#include "FactMetaData.h"
#include "ForeViewCamera.h"
#include "ForeViewMode.h"
#include "QGCLoggingCategory.h"

#include <QtCore/QApplicationStatic>
#include <QtCore/QFile>
#include <QtQml/QQmlApplicationEngine>
#include <QtQml/QQmlEngine>
#include <QtQml/qqml.h>

QGC_LOGGING_CATEGORY(ForeViewPluginLog, "ForeView.Plugin")

Q_APPLICATION_STATIC(ForeViewPlugin, _foreViewPluginInstance);

ForeViewPlugin::ForeViewPlugin(QObject *parent)
    : QGCCorePlugin(parent)
{
    // Customer mode until the company password unlocks Debug Mode.
    _showAdvancedUI = false;
}

QGCCorePlugin *ForeViewPlugin::instance()
{
    return _foreViewPluginInstance();
}

void ForeViewPlugin::_createObjects()
{
    if (_mode) {
        return;
    }

    _mode = new ForeViewMode(this);
    _camera = new ForeViewCamera(this);

    (void) connect(_mode, &ForeViewMode::debugModeChanged, this, &ForeViewPlugin::_syncAdvancedUI);

    // QGC can also turn advanced UI on from its own dialogs (e.g. tapping the version number).
    // Advanced UI must only ever follow Debug Mode, so undo any other change.
    (void) connect(this, &QGCCorePlugin::showAdvancedUIChanged, this, &ForeViewPlugin::_syncAdvancedUI);
}

void ForeViewPlugin::_syncAdvancedUI()
{
    const bool debugMode = _mode && _mode->debugMode();
    if (_showAdvancedUI != debugMode) {
        _showAdvancedUI = debugMode;
        emit showAdvancedUIChanged(debugMode);
    }
}

void ForeViewPlugin::init()
{
    QGCCorePlugin::init();
    _createObjects();
}

void ForeViewPlugin::cleanup()
{
    if (_qmlEngine && _interceptor) {
        _qmlEngine->removeUrlInterceptor(_interceptor);
    }
    delete _interceptor;
    _interceptor = nullptr;
    _qmlEngine = nullptr;
}

QQmlApplicationEngine *ForeViewPlugin::createQmlApplicationEngine(QObject *parent)
{
    _createObjects();

    _qmlEngine = QGCCorePlugin::createQmlApplicationEngine(parent);
    _interceptor = new ForeViewOverrideInterceptor();
    _qmlEngine->addUrlInterceptor(_interceptor);

    // import ForeView: ForeViewMode.debugMode, ForeViewCamera.takePhoto(), ...
    QQmlEngine::setObjectOwnership(_mode, QQmlEngine::CppOwnership);
    QQmlEngine::setObjectOwnership(_camera, QQmlEngine::CppOwnership);
    (void) qmlRegisterSingletonInstance("ForeView", 1, 0, "ForeViewMode", _mode);
    (void) qmlRegisterSingletonInstance("ForeView", 1, 0, "ForeViewCamera", _camera);

    return _qmlEngine;
}

void ForeViewPlugin::paletteOverride(const QString &colorName, QGCPalette::PaletteColorInfo_t &colorInfo)
{
    // ForeView palette: Horizon blue leads, Canopy green marks mission items.
    // Light = the "Outdoor" scheme (ForeView's default), Dark = "Indoor".
    struct Override {
        const char *name;
        const char *light;
        const char *dark;
    };
    static constexpr Override kOverrides[] = {
        { "window",              "#f5f8fa",   "#0f1b26" },
        { "windowTransparent",   "#ccf5f8fa", "#cc0f1b26" },
        { "windowShade",         "#dde6ec",   "#1b2a38" },
        { "windowShadeDark",     "#c9d6df",   "#142230" },
        { "button",              "#ffffff",   "#24384a" },
        { "buttonBorder",        "#0e5a8a",   "#5b7487" },
        { "buttonHighlight",     "#0e5a8a",   "#38c6f4" },
        { "buttonHighlightText", "#ffffff",   "#04202c" },
        { "primaryButton",       "#0e5a8a",   "#38c6f4" },
        { "primaryButtonText",   "#ffffff",   "#04202c" },
        { "groupBorder",         "#0e5a8a",   "#3b5468" },
        { "mapButtonHighlight",  "#0e5a8a",   "#38c6f4" },
        { "mapIndicator",        "#0e5a8a",   "#1c7fb8" },
        { "mapIndicatorChild",   "#1f7a55",   "#1f7a55" },
        { "missionItemEditor",   "#e3eff7",   "#1e3a52" },
        { "toolStripHoverColor", "#c9d6df",   "#24557a" },
        { "brandingPurple",      "#0e5a8a",   "#0e5a8a" },
        { "brandingBlue",        "#38c6f4",   "#38c6f4" },
        { "mapMissionTrajectory", "#2e9a6b",  "#2e9a6b" },
        { "surveyPolygonInterior", "#1f7a55", "#1f7a55" },
    };

    for (const Override &entry : kOverrides) {
        if (colorName == QLatin1String(entry.name)) {
            colorInfo[QGCPalette::Light][QGCPalette::ColorGroupEnabled] = QColor(QString::fromLatin1(entry.light));
            colorInfo[QGCPalette::Dark][QGCPalette::ColorGroupEnabled] = QColor(QString::fromLatin1(entry.dark));
            return;
        }
    }
}

void ForeViewPlugin::adjustSettingMetaData(const QString &settingsGroup, FactMetaData &metaData, bool &userVisible)
{
    QGCCorePlugin::adjustSettingMetaData(settingsGroup, metaData, userVisible);

    // Light "Outdoor" colours by default on every platform: easier to read in sunlight.
    if ((settingsGroup == AppSettings::settingsGroup) && (metaData.name() == AppSettings::indoorPaletteName)) {
        metaData.setRawDefaultValue(0);
    }
}

/*===========================================================================*/

QUrl ForeViewOverrideInterceptor::intercept(const QUrl &url, QQmlAbstractUrlInterceptor::DataType type)
{
    if (type != QQmlAbstractUrlInterceptor::QmlFile && type != QQmlAbstractUrlInterceptor::UrlString) {
        return url;
    }

    // Plain resources (qrc:/res/X) and tinted icons, which QGCColoredImage loads
    // through its image provider as image://coloredsvg/res/X?color=...
    const bool isResource = url.scheme() == QStringLiteral("qrc");
    const bool isTintedIcon = url.scheme() == QStringLiteral("image") && url.host() == QStringLiteral("coloredsvg");
    if (!isResource && !isTintedIcon) {
        return url;
    }

    const QString overridePath = QStringLiteral("/Custom%1").arg(url.path());
    if (!QFile::exists(QLatin1Char(':') + overridePath)) {
        return url;
    }

    QUrl result(url);
    result.setPath(overridePath);
    qCDebug(ForeViewPluginLog) << "Using ForeView override" << result.toString();
    return result;
}
