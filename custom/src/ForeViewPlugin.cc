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
    if ((type == QQmlAbstractUrlInterceptor::QmlFile || type == QQmlAbstractUrlInterceptor::UrlString)
            && url.scheme() == QStringLiteral("qrc")) {
        const QString overridePath = QStringLiteral("/Custom%1").arg(url.path());
        if (QFile::exists(QLatin1Char(':') + overridePath)) {
            QUrl result;
            result.setScheme(QStringLiteral("qrc"));
            result.setPath(overridePath);
            return result;
        }
    }
    return url;
}
