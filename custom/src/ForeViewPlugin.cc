#include "ForeViewPlugin.h"

#include <QtCore/QApplicationStatic>
#include <QtCore/QFile>
#include <QtQml/QQmlApplicationEngine>

Q_APPLICATION_STATIC(ForeViewPlugin, _foreViewPluginInstance);

ForeViewPlugin::ForeViewPlugin(QObject *parent)
    : QGCCorePlugin(parent)
{
}

QGCCorePlugin *ForeViewPlugin::instance()
{
    return _foreViewPluginInstance();
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
    _qmlEngine = QGCCorePlugin::createQmlApplicationEngine(parent);
    _interceptor = new ForeViewOverrideInterceptor();
    _qmlEngine->addUrlInterceptor(_interceptor);
    return _qmlEngine;
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
    return result;
}
