#pragma once

#include <QtCore/QMap>
#include <QtCore/QObject>
#include <QtCore/QSet>
#include <QtCore/QTimer>
#include <QtNetwork/QHostAddress>
#include <QtQmlIntegration/QtQmlIntegration>

class QUdpSocket;

/// Changes the video encoding of SIYI gimbal cameras (A8 mini, ZR10, ZR30, ZT6, ZT30)
/// through SIYI's camera SDK protocol (UDP port 37260 on the camera).
///
/// Used by live streaming: RTMP needs H.264, while SIYI cameras can be set to H.265.
/// Only the encoding type is changed; each stream keeps its resolution and bitrate.
class SiyiCameraEncoding : public QObject
{
    Q_OBJECT
    QML_ELEMENT
    QML_UNCREATABLE("")

    Q_PROPERTY(bool    busy        READ busy        NOTIFY busyChanged)
    Q_PROPERTY(QString statusText  READ statusText  NOTIFY statusTextChanged)

public:
    explicit SiyiCameraEncoding(QObject *parent = nullptr);

    bool busy() const { return _step != Step::Idle; }
    QString statusText() const { return _statusText; }

    /// Switches every H.265 video stream (main and sub) of the SIYI camera at @p host to H.264.
    Q_INVOKABLE void switchToH264(const QString &host);

    /// Builds a SIYI SDK frame (exposed for tests).
    static QByteArray buildFrame(quint8 cmdId, const QByteArray &data, quint16 seq);
    /// CRC-16/XMODEM as used by the SIYI SDK (exposed for tests).
    static quint16 crc16(const QByteArray &bytes);

signals:
    void busyChanged();
    void statusTextChanged();
    /// At least one stream was switched to H.264; the RTSP stream restarts with the new codec.
    void switched();

private:
    enum class Step {
        Idle,
        Query,
        Set
    };

    struct StreamParams {
        quint8 encoding = 0;    // 1 = H.264, 2 = H.265
        quint16 width = 0;
        quint16 height = 0;
        quint16 kbps = 0;
    };

    void _onReadyRead();
    void _onRetryTimer();
    void _sendQueries();
    void _sendSets();
    void _finish(const QString &statusText, bool switchedAny);
    void _setStatus(const QString &text);
    void _send(quint8 cmdId, const QByteArray &data);
    static bool _parseFrame(const QByteArray &datagram, quint8 &cmdId, QByteArray &data);

    QUdpSocket *_socket = nullptr;
    QTimer _retryTimer;
    QHostAddress _host;
    Step _step = Step::Idle;
    int _attempts = 0;
    quint16 _seq = 0;
    QMap<quint8, StreamParams> _streams;    // by stream type: 1 = main, 2 = sub
    QSet<quint8> _pending;                  // streams still waiting for a reply in the current step
    QSet<quint8> _switchedStreams;
    QString _statusText;

    static constexpr quint16 kPort = 37260;
    static constexpr quint8 kCmdGetEncoding = 0x20;
    static constexpr quint8 kCmdSetEncoding = 0x21;
    static constexpr quint8 kEncodingH264 = 1;
    static constexpr quint8 kEncodingH265 = 2;
    static constexpr int kRetryIntervalMs = 700;
    static constexpr int kMaxAttempts = 3;
};
