#pragma once

#include <QtCore/QList>
#include <QtCore/QObject>
#include <QtCore/QPointer>
#include <QtCore/QTimer>

class ForeViewMode;
class LinkConfiguration;

/// Drone connection helper for customer mode.
///
/// - connectDrone(): what tapping "Not connected" does. Connects the saved links that have
///   "Automatically Connect on Start" turned on (or the only saved link if none has it) and says
///   what happened.
/// - While no drone is connected in customer mode, it quietly retries auto-connect links that
///   are down: QGC tries them only once at start-up, so a link that was not reachable then (radio
///   or network not up yet) never came back. TCP links are probed first so a failed retry does
///   not pop up an error every few seconds. (A UDP port that cannot be bound is retried by
///   UDPLink itself.)
class ForeViewLinks : public QObject
{
    Q_OBJECT

public:
    explicit ForeViewLinks(ForeViewMode *mode, QObject *parent = nullptr);

    Q_INVOKABLE void connectDrone();

signals:
    /// Short message for the pilot, e.g. "Connecting to MK15…".
    void notice(const QString &text, bool error);

private:
    /// Saved links with "Automatically Connect on Start"; with fallbackToOnlyLink, the only
    /// saved (non-dynamic) link when none has it.
    static QList<LinkConfiguration *> _targets(bool fallbackToOnlyLink);
    void _retry();
    void _probeTcpThenConnect(LinkConfiguration *config);

    ForeViewMode *_mode = nullptr;
    QTimer _retryTimer;
    QList<QPointer<LinkConfiguration>> _probing;

    static constexpr int kRetryIntervalMs = 5000;
    static constexpr int kTcpProbeTimeoutMs = 3000;
};
