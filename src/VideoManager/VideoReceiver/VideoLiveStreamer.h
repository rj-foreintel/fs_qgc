#pragma once

#include <QtCore/QObject>
#include <QtCore/QString>
#include <QtQmlIntegration/QtQmlIntegration>

/// Forwards the received camera video to an RTMP/RTMPS server ("Go Live").
///
/// The video is forwarded still encoded (no re-encode). Implementations run
/// separately from the receiver's display pipeline, so a slow or unreachable
/// server never affects the video shown to the pilot.
///
/// All properties change on the GUI thread only.
class VideoLiveStreamer : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("")

    Q_PROPERTY(State   state        READ state        NOTIFY stateChanged)
    Q_PROPERTY(bool    active       READ active       NOTIFY stateChanged)
    Q_PROPERTY(QString statusText   READ statusText   NOTIFY stateChanged)
    Q_PROPERTY(QString codec        READ codec        NOTIFY statsChanged)
    Q_PROPERTY(int     bitrateKbps  READ bitrateKbps  NOTIFY statsChanged)

public:
    enum State {
        Idle,               ///< Not streaming
        WaitingForVideo,    ///< Started, but no camera video is arriving
        Connecting,         ///< Connecting to the server
        Live,               ///< Video is reaching the server
        Reconnecting,       ///< Connection failed or dropped; retrying automatically
        Failed,             ///< Cannot stream; retrying will not help (see statusText)
    };
    Q_ENUM(State)

    explicit VideoLiveStreamer(QObject *parent = nullptr)
        : QObject(parent)
    {}

    State state() const { return _state; }
    bool active() const { return _state != Idle; }
    QString statusText() const { return _statusText; }
    QString codec() const { return _codec; }
    int bitrateKbps() const { return _bitrateKbps; }

    /// Starts (or restarts with a new URL) publishing to @p url (rtmp:// or rtmps://).
    virtual void start(const QString &url) = 0;
    /// Stops publishing and closes the server connection.
    virtual void stop() = 0;

signals:
    void stateChanged();
    void statsChanged();

protected:
    void setState(State state, const QString &statusText)
    {
        if ((state != _state) || (statusText != _statusText)) {
            _state = state;
            _statusText = statusText;
            emit stateChanged();
        }
    }

    void setStats(const QString &codec, int bitrateKbps)
    {
        if ((codec != _codec) || (bitrateKbps != _bitrateKbps)) {
            _codec = codec;
            _bitrateKbps = bitrateKbps;
            emit statsChanged();
        }
    }

private:
    State _state = Idle;
    QString _statusText;
    QString _codec;
    int _bitrateKbps = 0;
};
