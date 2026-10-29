#include "ForeViewLinks.h"

#include "ForeViewMode.h"
#include "LinkConfiguration.h"
#include "LinkInterface.h"
#include "LinkManager.h"
#include "MultiVehicleManager.h"
#include "QGCLoggingCategory.h"
#include "QmlObjectListModel.h"
#include "TCPLink.h"

#include <QtCore/QStringList>
#include <QtNetwork/QAbstractSocket>
#include <QtNetwork/QTcpSocket>

#include <memory>

QGC_LOGGING_CATEGORY(ForeViewLinksLog, "ForeView.Links")

ForeViewLinks::ForeViewLinks(ForeViewMode *mode, QObject *parent)
    : QObject(parent)
    , _mode(mode)
{
    _retryTimer.setInterval(kRetryIntervalMs);
    (void) connect(&_retryTimer, &QTimer::timeout, this, &ForeViewLinks::_retry);
    _retryTimer.start();
}

QList<LinkConfiguration *> ForeViewLinks::_targets(bool fallbackToOnlyLink)
{
    QList<LinkConfiguration *> autoConnect;
    QList<LinkConfiguration *> saved;

    // LinkManager lists its configurations only through this QML property.
    const QmlObjectListModel *configs = LinkManager::instance()->property("linkConfigurations").value<QmlObjectListModel *>();
    if (!configs) {
        return autoConnect;
    }

    for (int i = 0; i < configs->count(); ++i) {
        LinkConfiguration *config = qobject_cast<LinkConfiguration *>(const_cast<QmlObjectListModel *>(configs)->get(i));
        if (!config || (config->type() == LinkConfiguration::TypeLogReplay)) {
            continue;
        }
        if (config->isAutoConnect()) {
            autoConnect.append(config);
        } else if (!config->isDynamic()) {
            saved.append(config);
        }
    }

    if (autoConnect.isEmpty() && fallbackToOnlyLink && (saved.size() == 1)) {
        return saved;
    }
    return autoConnect;
}

void ForeViewLinks::connectDrone()
{
    const QList<LinkConfiguration *> targets = _targets(true);
    if (targets.isEmpty()) {
        emit notice(tr("No saved drone connection. In Debug Mode, add one in Settings > Comm Links and turn on \"Automatically Connect on Start\"."), true);
        return;
    }

    QStringList connecting;
    QStringList listening;
    for (LinkConfiguration *config : targets) {
        if (config->link()) {
            // Already open (a UDP link that could not bind keeps retrying by itself).
            listening.append(config->name());
            continue;
        }
        qCDebug(ForeViewLinksLog) << "Connecting" << config->name();
        LinkManager::instance()->createConnectedLink(config);
        connecting.append(config->name());
    }

    if (!connecting.isEmpty()) {
        emit notice(tr("Connecting to %1…").arg(connecting.join(QStringLiteral(", "))), false);
    } else {
        emit notice(tr("Listening on %1 but no data from the drone. Check that the drone is powered and the remote is linked.").arg(listening.join(QStringLiteral(", "))), false);
    }
}

void ForeViewLinks::_retry()
{
    // Debug Mode leaves links exactly as the engineer set them (e.g. disconnected on purpose).
    if ((_mode && _mode->debugMode()) || MultiVehicleManager::instance()->activeVehicle()) {
        return;
    }

    for (LinkConfiguration *config : _targets(false)) {
        if (config->link()) {
            continue;
        }

        switch (config->type()) {
        case LinkConfiguration::TypeUdp:
            qCDebug(ForeViewLinksLog) << "Retrying" << config->name();
            LinkManager::instance()->createConnectedLink(config);
            break;
        case LinkConfiguration::TypeTcp:
            _probeTcpThenConnect(config);
            break;
        default:
            // Serial and Bluetooth: QGC's own USB auto-connect handles serial devices.
            break;
        }
    }
}

void ForeViewLinks::_probeTcpThenConnect(LinkConfiguration *config)
{
    const TCPConfiguration *tcpConfig = qobject_cast<const TCPConfiguration *>(config);
    if (!tcpConfig || tcpConfig->host().isEmpty()) {
        return;
    }

    _probing.removeIf([](const QPointer<LinkConfiguration> &probed) { return probed.isNull(); });
    if (_probing.contains(config)) {
        return;
    }
    _probing.append(config);

    QTcpSocket *socket = new QTcpSocket(this);
    const QPointer<LinkConfiguration> target(config);
    const auto done = std::make_shared<bool>(false);

    auto finish = [this, socket, target, done](bool reachable) {
        if (*done) {
            return;
        }
        *done = true;
        _probing.removeIf([target](const QPointer<LinkConfiguration> &probed) { return probed.isNull() || (probed == target); });
        socket->abort();
        socket->deleteLater();

        if (reachable && target && !target->link() && !MultiVehicleManager::instance()->activeVehicle()) {
            qCDebug(ForeViewLinksLog) << "Drone reachable again, connecting" << target->name();
            LinkManager::instance()->createConnectedLink(target.data());
        }
    };

    (void) connect(socket, &QTcpSocket::connected, this, [finish]() { finish(true); });
    (void) connect(socket, &QTcpSocket::errorOccurred, this, [finish]() { finish(false); });
    QTimer::singleShot(kTcpProbeTimeoutMs, socket, [finish]() { finish(false); });

    socket->connectToHost(tcpConfig->host(), tcpConfig->port());
}
