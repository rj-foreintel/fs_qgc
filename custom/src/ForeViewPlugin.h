#pragma once

#include <QtQml/QQmlAbstractUrlInterceptor>

#include "QGCCorePlugin.h"

class QQmlApplicationEngine;

/// Redirects qrc:/X to qrc:/Custom/X when ForeView ships its own version of that
/// resource (logos, window icon). Everything else resolves to the stock QGC file.
class ForeViewOverrideInterceptor : public QQmlAbstractUrlInterceptor
{
public:
    QUrl intercept(const QUrl &url, QQmlAbstractUrlInterceptor::DataType type) final;
};

/// ForeView core plugin. Branding only: it keeps QGC's standard options,
/// settings and flight-stack support, and swaps in ForeView artwork.
class ForeViewPlugin : public QGCCorePlugin
{
    Q_OBJECT

public:
    explicit ForeViewPlugin(QObject *parent = nullptr);

    static QGCCorePlugin *instance();

    void cleanup() final;
    QQmlApplicationEngine *createQmlApplicationEngine(QObject *parent) final;
    QString stableDownloadLocation() const final { return QString(); }

private:
    QQmlApplicationEngine *_qmlEngine = nullptr;
    ForeViewOverrideInterceptor *_interceptor = nullptr;
};
