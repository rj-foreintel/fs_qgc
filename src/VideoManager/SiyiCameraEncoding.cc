#include "SiyiCameraEncoding.h"

#include "QGCLoggingCategory.h"

#include <QtCore/QtEndian>
#include <QtNetwork/QUdpSocket>

QGC_LOGGING_CATEGORY(SiyiCameraEncodingLog, "Video.SiyiCameraEncoding")

// SIYI SDK frame:
//   STX 0x55 0x66 | CTRL (0x01 = need ack) | DATA_LEN (u16 LE) | SEQ (u16 LE) | CMD_ID | DATA | CRC16 (u16 LE)
// CRC16 is CRC-16/XMODEM (poly 0x1021, init 0) over everything before it.
//
// 0x20 get encoding:  req [stream_type]
//                     ack [stream_type, enc_type, width u16, height u16, kbps u16, fps]
// 0x21 set encoding:  req [stream_type, enc_type, width u16, height u16, kbps u16, reserved]
//                     ack [stream_type, success]
// stream_type: 1 = main, 2 = sub. enc_type: 1 = H.264, 2 = H.265.

SiyiCameraEncoding::SiyiCameraEncoding(QObject *parent)
    : QObject(parent)
    , _socket(new QUdpSocket(this))
{
    _retryTimer.setInterval(kRetryIntervalMs);
    (void) connect(&_retryTimer, &QTimer::timeout, this, &SiyiCameraEncoding::_onRetryTimer);
    (void) connect(_socket, &QUdpSocket::readyRead, this, &SiyiCameraEncoding::_onReadyRead);
}

quint16 SiyiCameraEncoding::crc16(const QByteArray &bytes)
{
    quint16 crc = 0;
    for (const char byte : bytes) {
        crc ^= static_cast<quint16>(static_cast<quint8>(byte)) << 8;
        for (int bit = 0; bit < 8; ++bit) {
            crc = (crc & 0x8000) ? static_cast<quint16>((crc << 1) ^ 0x1021) : static_cast<quint16>(crc << 1);
        }
    }
    return crc;
}

QByteArray SiyiCameraEncoding::buildFrame(quint8 cmdId, const QByteArray &data, quint16 seq)
{
    QByteArray frame;
    frame.reserve(10 + data.size());
    frame.append(char(0x55));
    frame.append(char(0x66));
    frame.append(char(0x01));
    const quint16 length = static_cast<quint16>(data.size());
    frame.append(char(length & 0xff));
    frame.append(char(length >> 8));
    frame.append(char(seq & 0xff));
    frame.append(char(seq >> 8));
    frame.append(char(cmdId));
    frame.append(data);
    const quint16 crc = crc16(frame);
    frame.append(char(crc & 0xff));
    frame.append(char(crc >> 8));
    return frame;
}

bool SiyiCameraEncoding::_parseFrame(const QByteArray &datagram, quint8 &cmdId, QByteArray &data)
{
    if ((datagram.size() < 10) || (static_cast<quint8>(datagram[0]) != 0x55) || (static_cast<quint8>(datagram[1]) != 0x66)) {
        return false;
    }

    const quint16 length = qFromLittleEndian<quint16>(datagram.constData() + 3);
    if (datagram.size() < (10 + length)) {
        return false;
    }

    const QByteArray body = datagram.left(8 + length);
    const quint16 crc = qFromLittleEndian<quint16>(datagram.constData() + 8 + length);
    if (crc16(body) != crc) {
        return false;
    }

    cmdId = static_cast<quint8>(datagram[7]);
    data = datagram.mid(8, length);
    return true;
}

void SiyiCameraEncoding::switchToH264(const QString &host)
{
    if (busy()) {
        return;
    }

    _host = QHostAddress(host);
    if (_host.isNull()) {
        _setStatus(tr("Cannot reach the camera: \"%1\" is not an IP address. Check the RTSP URL in Settings > Video.").arg(host));
        return;
    }

    if ((_socket->state() != QAbstractSocket::BoundState) && !_socket->bind(QHostAddress(QHostAddress::AnyIPv4), 0)) {
        _setStatus(tr("Could not open a network socket: %1").arg(_socket->errorString()));
        return;
    }

    qCDebug(SiyiCameraEncodingLog) << "Switching SIYI camera at" << _host.toString() << "to H.264";

    _streams.clear();
    _switchedStreams.clear();
    _pending = {1, 2};
    _step = Step::Query;
    _attempts = 0;
    emit busyChanged();
    _setStatus(tr("Contacting the camera..."));

    _sendQueries();
    _retryTimer.start();
}

void SiyiCameraEncoding::_send(quint8 cmdId, const QByteArray &data)
{
    const QByteArray frame = buildFrame(cmdId, data, _seq++);
    (void) _socket->writeDatagram(frame, _host, kPort);
}

void SiyiCameraEncoding::_sendQueries()
{
    for (const quint8 stream : std::as_const(_pending)) {
        _send(kCmdGetEncoding, QByteArray(1, char(stream)));
    }
}

void SiyiCameraEncoding::_sendSets()
{
    for (const quint8 stream : std::as_const(_pending)) {
        const StreamParams &params = _streams[stream];
        QByteArray data;
        data.append(char(stream));
        data.append(char(kEncodingH264));
        data.append(char(params.width & 0xff));
        data.append(char(params.width >> 8));
        data.append(char(params.height & 0xff));
        data.append(char(params.height >> 8));
        data.append(char(params.kbps & 0xff));
        data.append(char(params.kbps >> 8));
        data.append(char(0));
        _send(kCmdSetEncoding, data);
    }
}

void SiyiCameraEncoding::_onReadyRead()
{
    while (_socket->hasPendingDatagrams()) {
        QByteArray datagram(static_cast<int>(_socket->pendingDatagramSize()), Qt::Uninitialized);
        QHostAddress sender;
        (void) _socket->readDatagram(datagram.data(), datagram.size(), &sender);

        quint8 cmdId = 0;
        QByteArray data;
        if ((_step == Step::Idle) || !_parseFrame(datagram, cmdId, data) || data.isEmpty()) {
            continue;
        }

        const quint8 stream = static_cast<quint8>(data[0]);
        if ((_step == Step::Query) && (cmdId == kCmdGetEncoding) && (data.size() >= 8) && _pending.contains(stream)) {
            StreamParams params;
            params.encoding = static_cast<quint8>(data[1]);
            params.width = qFromLittleEndian<quint16>(data.constData() + 2);
            params.height = qFromLittleEndian<quint16>(data.constData() + 4);
            params.kbps = qFromLittleEndian<quint16>(data.constData() + 6);
            _streams.insert(stream, params);
            _pending.remove(stream);
            qCDebug(SiyiCameraEncodingLog) << "Stream" << stream << "encoding" << params.encoding
                                           << params.width << "x" << params.height << params.kbps << "kbps";
        } else if ((_step == Step::Set) && (cmdId == kCmdSetEncoding) && (data.size() >= 2) && _pending.contains(stream)) {
            _pending.remove(stream);
            if (data[1] != 0) {
                (void) _switchedStreams.insert(stream);
            }
            qCDebug(SiyiCameraEncodingLog) << "Stream" << stream << "set to H.264:" << (data[1] != 0);
        }
    }

    if (_pending.isEmpty()) {
        _onRetryTimer();    // every stream answered; move on without waiting for the timer
    }
}

void SiyiCameraEncoding::_onRetryTimer()
{
    if (!_pending.isEmpty() && (++_attempts < kMaxAttempts)) {
        if (_step == Step::Query) {
            _sendQueries();
        } else if (_step == Step::Set) {
            _sendSets();
        }
        return;
    }

    if (_step == Step::Query) {
        if (_streams.isEmpty()) {
            _finish(tr("No reply from a SIYI camera at %1. Check that the camera is powered and the RTSP URL points to it.").arg(_host.toString()), false);
            return;
        }

        _pending.clear();
        for (auto it = _streams.cbegin(); it != _streams.cend(); ++it) {
            if (it.value().encoding == kEncodingH265) {
                (void) _pending.insert(it.key());
            }
        }

        if (_pending.isEmpty()) {
            _finish(tr("The camera is already set to H.264."), false);
            return;
        }

        _step = Step::Set;
        _attempts = 0;
        _setStatus(tr("Switching the camera to H.264..."));
        _sendSets();
        _retryTimer.start();
        return;
    }

    if (_step == Step::Set) {
        if (_switchedStreams.isEmpty()) {
            _finish(tr("The camera did not accept the change. Set Coding Format to H.264 with SIYI Assistant instead."), false);
        } else {
            _finish(tr("Camera switched to H.264. The video reconnects in a few seconds."), true);
        }
    }
}

void SiyiCameraEncoding::_finish(const QString &statusText, bool switchedAny)
{
    _retryTimer.stop();
    _step = Step::Idle;
    _pending.clear();
    emit busyChanged();
    _setStatus(statusText);
    qCDebug(SiyiCameraEncodingLog) << statusText;
    if (switchedAny) {
        emit switched();
    }
}

void SiyiCameraEncoding::_setStatus(const QString &text)
{
    if (text != _statusText) {
        _statusText = text;
        emit statusTextChanged();
    }
}
