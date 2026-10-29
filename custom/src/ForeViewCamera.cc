#include "ForeViewCamera.h"

#include "Fact.h"
#include "QGCLoggingCategory.h"
#include "SettingsManager.h"
#include "SiyiCameraEncoding.h"
#include "VideoSettings.h"

#include <QtCore/QSettings>
#include <QtCore/QUrl>
#include <QtCore/QtEndian>
#include <QtNetwork/QUdpSocket>

QGC_LOGGING_CATEGORY(ForeViewCameraLog, "ForeView.Camera")

namespace {
    // SIYI cameras ship with this address; used when the RTSP URL does not name an IP address.
    constexpr const char *kDefaultCameraHost = "192.168.144.25";

    constexpr const char *kSettingsGroup = "ForeViewCamera";
    constexpr const char *kPaletteKey = "thermalPalette";
    constexpr const char *kHighRangeKey = "thermalHighRange";
}

ForeViewCamera::ForeViewCamera(QObject *parent)
    : QObject(parent)
    , _socket(new QUdpSocket(this))
{
    // The camera cannot report its thermal colours or range, so remember what was last chosen here.
    QSettings settings;
    settings.beginGroup(kSettingsGroup);
    _thermalPalette = settings.value(kPaletteKey, 0).toInt();
    _thermalHighRange = settings.value(kHighRangeKey, false).toBool();
    settings.endGroup();

    (void) connect(_socket, &QUdpSocket::readyRead, this, &ForeViewCamera::_onReadyRead);
    (void) connect(SettingsManager::instance()->videoSettings()->rtspUrl(), &Fact::rawValueChanged, this, &ForeViewCamera::_rtspUrlChanged);

    _pollTimer.setInterval(kPollIntervalMs);
    (void) connect(&_pollTimer, &QTimer::timeout, this, &ForeViewCamera::_poll);
    _pollTimer.start();
    QTimer::singleShot(0, this, &ForeViewCamera::_poll);
}

QString ForeViewCamera::modelFromHardwareId(char first, char second)
{
    struct HardwareId {
        char id[2];
        const char *model;
    };
    static constexpr HardwareId kHardwareIds[] = {
        { { '7', '5' }, "A2" },
        { { '7', '3' }, "A8 mini" },
        { { '6', 'B' }, "ZR10" },
        { { '7', '8' }, "ZR30" },
        { { '8', '3' }, "ZT6" },
        { { '7', 'A' }, "ZT30" },
    };

    for (const HardwareId &entry : kHardwareIds) {
        if ((entry.id[0] == first) && (entry.id[1] == second)) {
            return QString::fromLatin1(entry.model);
        }
    }
    return QStringLiteral("SIYI");
}

QString ForeViewCamera::otherStreamUrl(const QString &rtspUrl)
{
    QUrl url(rtspUrl.trimmed());
    QString path = url.path();
    if (!url.isValid() || (url.scheme().toLower() != QStringLiteral("rtsp"))) {
        return QString();
    }
    if (path.endsWith(QStringLiteral("/video1"))) {
        path.replace(path.size() - 1, 1, QLatin1Char('2'));
    } else if (path.endsWith(QStringLiteral("/video2"))) {
        path.replace(path.size() - 1, 1, QLatin1Char('1'));
    } else {
        return QString();
    }
    url.setPath(path);
    return url.toString();
}

QString ForeViewCamera::_rtspUrl()
{
    return SettingsManager::instance()->videoSettings()->rtspUrl()->rawValue().toString();
}

bool ForeViewCamera::_updateHost()
{
    QHostAddress host(QUrl(_rtspUrl().trimmed()).host());
    if (host.isNull()) {
        host = QHostAddress(QString::fromLatin1(kDefaultCameraHost));
    }

    if (host != _host) {
        _host = host;
        _setConnected(false);
        _model.clear();
    }

    if ((_socket->state() != QAbstractSocket::BoundState) && !_socket->bind(QHostAddress(QHostAddress::AnyIPv4), 0)) {
        qCWarning(ForeViewCameraLog) << "Could not open a socket for the camera:" << _socket->errorString();
        return false;
    }
    return true;
}

bool ForeViewCamera::_viewingSubStream() const
{
    // The ZT6 serves its main stream as .../video1 and its sub stream as .../video2. When the pilot
    // watches the sub stream, the sensor shown is the opposite of the "main" one in the image type.
    const QString path = QUrl(_rtspUrl().trimmed()).path();
    return path.endsWith(QStringLiteral("/video2"));
}

void ForeViewCamera::_poll()
{
    if (!_updateHost()) {
        return;
    }

    if (_connected && (++_missedPolls > kMissedPollsBeforeDisconnect)) {
        qCDebug(ForeViewCameraLog) << "Camera at" << _host.toString() << "stopped answering";
        _setConnected(false);
    }

    if (_model.isEmpty()) {
        _send(kCmdHardwareId, QByteArray());
    }
    _send(kCmdConfigInfo, QByteArray());
}

void ForeViewCamera::_send(quint8 cmdId, const QByteArray &data)
{
    if (_host.isNull()) {
        return;
    }
    const QByteArray frame = SiyiCameraEncoding::buildFrame(cmdId, data, _seq++);
    (void) _socket->writeDatagram(frame, _host, kPort);
}

bool ForeViewCamera::_parseFrame(const QByteArray &datagram, quint8 &cmdId, QByteArray &data)
{
    // STX 0x55 0x66 | CTRL | DATA_LEN (u16 LE) | SEQ (u16 LE) | CMD_ID | DATA | CRC16 (u16 LE)
    if ((datagram.size() < 10) || (static_cast<quint8>(datagram[0]) != 0x55) || (static_cast<quint8>(datagram[1]) != 0x66)) {
        return false;
    }

    const quint16 length = qFromLittleEndian<quint16>(datagram.constData() + 3);
    if (datagram.size() < (10 + length)) {
        return false;
    }

    const quint16 crc = qFromLittleEndian<quint16>(datagram.constData() + 8 + length);
    if (SiyiCameraEncoding::crc16(datagram.left(8 + length)) != crc) {
        return false;
    }

    cmdId = static_cast<quint8>(datagram[7]);
    data = datagram.mid(8, length);
    return true;
}

void ForeViewCamera::_onReadyRead()
{
    while (_socket->hasPendingDatagrams()) {
        QByteArray datagram(static_cast<int>(_socket->pendingDatagramSize()), Qt::Uninitialized);
        QHostAddress sender;
        (void) _socket->readDatagram(datagram.data(), datagram.size(), &sender);

        quint8 cmdId = 0;
        QByteArray data;
        if (_parseFrame(datagram, cmdId, data)) {
            _handleFrame(cmdId, data);
        }
    }
}

void ForeViewCamera::_handleFrame(quint8 cmdId, const QByteArray &data)
{
    _missedPolls = 0;

    switch (cmdId) {
    case kCmdHardwareId:
        if (data.size() >= 2) {
            const QString newModel = modelFromHardwareId(data[0], data[1]);
            if (newModel != _model) {
                _model = newModel;
                qCDebug(ForeViewCameraLog) << "Camera model" << _model << "at" << _host.toString();
                if (!thermalSupported()) {
                    setSideBySide(false);
                }
                _requestState();
                emit connectedChanged();
            }
        }
        _setConnected(true);
        break;

    case kCmdConfigInfo:
        // [reserved, hdr, reserved, record_status, motion_mode, mounting_dir, video_output]
        if (data.size() >= 4) {
            const quint8 recordStatus = static_cast<quint8>(data[3]);
            if (recordStatus != _recordStatus) {
                _recordStatus = recordStatus;
                emit recordingChanged();
            }
        }
        _setConnected(true);
        break;

    case kCmdFunctionFeedback:
        if (!data.isEmpty()) {
            const quint8 feedback = static_cast<quint8>(data[0]);
            if (feedback == kFeedbackSuccess && _photoPending) {
                _photoPending = false;
                emit notice(tr("Photo saved to the camera's SD card"), false);
            } else if (feedback == kFeedbackPhotoFailed) {
                _photoPending = false;
                emit notice(tr("The camera could not take a photo. Check its SD card."), true);
            } else if (feedback == kFeedbackRecordFailed) {
                emit notice(tr("The camera could not record. Check its SD card."), true);
            }
        }
        break;

    case kCmdManualZoom:
        if (data.size() >= 2) {
            const double newZoom = qFromLittleEndian<quint16>(data.constData()) / 10.0;
            if ((newZoom >= 1.0) && !qFuzzyCompare(newZoom, _zoom)) {
                _zoom = newZoom;
                emit zoomChanged();
            }
        }
        break;

    case kCmdGetThermalPalette:
    case kCmdSetThermalPalette:
        if (!data.isEmpty()) {
            const int palette = static_cast<quint8>(data[0]);
            if ((palette <= 11) && (palette != _thermalPalette)) {
                _thermalPalette = palette;
                emit thermalPaletteChanged();
            }
        }
        break;

    case kCmdGetThermalGain:
    case kCmdSetThermalGain:
        if (!data.isEmpty()) {
            const quint8 gain = static_cast<quint8>(data[0]);
            if ((gain == kGainLow) || (gain == kGainHigh)) {
                const bool highRange = (gain == kGainLow);
                if (highRange != _thermalHighRange) {
                    _thermalHighRange = highRange;
                    emit thermalHighRangeChanged();
                }
            }
        }
        break;

    case kCmdGetImageType:
    case kCmdSetImageType:
        if (!data.isEmpty()) {
            const quint8 imageType = static_cast<quint8>(data[0]);
            const bool mainIsThermal = (imageType == kImageMainThermalSubZoom) || (imageType == kImageMainThermalSubWide);
            const bool newThermalView = mainIsThermal != _viewingSubStream();
            if (newThermalView != _thermalView) {
                _thermalView = newThermalView;
                emit thermalViewChanged();
            }
        }
        break;

    default:
        break;
    }
}

void ForeViewCamera::_setConnected(bool isConnected)
{
    if (isConnected != _connected) {
        _connected = isConnected;
        if (isConnected) {
            // The camera may have been power-cycled or changed from another app meanwhile.
            _requestState();
        } else {
            _recordStatus = 0;
            emit recordingChanged();
        }
        emit connectedChanged();
    }
}

void ForeViewCamera::_requestState()
{
    // "Stop zooming" is answered with the current zoom, so the zoom shown matches the camera.
    _send(kCmdManualZoom, static_cast<quint8>(0));

    if (thermalSupported()) {
        // The camera answers with its current image type, thermal colours and range. Cameras
        // that do not answer keep the last values chosen in ForeView.
        _send(kCmdGetImageType, QByteArray());
        _send(kCmdGetThermalPalette, QByteArray());
        _send(kCmdGetThermalGain, QByteArray());
    }
}

void ForeViewCamera::takePhoto()
{
    if (sdCardMissing()) {
        emit notice(tr("No SD card in the camera"), true);
        return;
    }
    _photoPending = true;
    _send(kCmdPhoto, kPhotoTake);
    // Not every firmware sends a feedback frame for photos, so confirm after a short wait.
    QTimer::singleShot(1500, this, [this]() {
        if (_photoPending) {
            _photoPending = false;
            emit notice(tr("Photo taken"), false);
        }
    });
}

void ForeViewCamera::toggleRecording()
{
    if (sdCardMissing()) {
        emit notice(tr("No SD card in the camera"), true);
        return;
    }
    _send(kCmdPhoto, kPhotoRecordToggle);
    // Read the new state back soon instead of waiting for the next poll.
    QTimer::singleShot(500, this, [this]() { _send(kCmdConfigInfo, QByteArray()); });
}

void ForeViewCamera::zoomIn()
{
    _send(kCmdManualZoom, static_cast<quint8>(1));
}

void ForeViewCamera::zoomOut()
{
    // The SDK takes -1 as an unsigned byte.
    _send(kCmdManualZoom, static_cast<quint8>(255));
}

void ForeViewCamera::zoomStop()
{
    _send(kCmdManualZoom, static_cast<quint8>(0));
}

void ForeViewCamera::center()
{
    _send(kCmdCenter, static_cast<quint8>(1));
}

void ForeViewCamera::setThermalView(bool thermal)
{
    if (!thermalSupported()) {
        return;
    }

    setSideBySide(false);
    _applyThermalView(thermal);
}

void ForeViewCamera::setSideBySide(bool on)
{
    if (on && !thermalSupported()) {
        return;
    }
    if (on && otherStreamUrl(_rtspUrl()).isEmpty()) {
        emit notice(tr("Side by side needs the camera's RTSP address ending in /video1 or /video2 (Settings > Video)."), true);
        return;
    }

    if (on) {
        // Colour on the stream the pilot watches, thermal on the other one.
        _applyThermalView(false);
    }

    if (on != _sideBySide) {
        _sideBySide = on;
        _secondaryStreamUrl = secondaryStreamUrl();
        emit sideBySideChanged();
    }
}

void ForeViewCamera::_rtspUrlChanged()
{
    if (!_sideBySide) {
        return;
    }
    if (otherStreamUrl(_rtspUrl()).isEmpty()) {
        setSideBySide(false);
        return;
    }

    _applyThermalView(false);
    const QString url = secondaryStreamUrl();
    if (url != _secondaryStreamUrl) {
        _secondaryStreamUrl = url;
        emit sideBySideChanged();
    }
}

void ForeViewCamera::_applyThermalView(bool thermal)
{
    const bool mainThermal = thermal != _viewingSubStream();
    _send(kCmdSetImageType, static_cast<quint8>(mainThermal ? kImageMainThermalSubZoom : kImageMainZoomSubThermal));

    if (thermal != _thermalView) {
        _thermalView = thermal;
        emit thermalViewChanged();
    }
}

void ForeViewCamera::setThermalPalette(int palette)
{
    if (!thermalSupported() || (palette < 0) || (palette > 11)) {
        return;
    }

    _send(kCmdSetThermalPalette, static_cast<quint8>(palette));

    if (palette != _thermalPalette) {
        _thermalPalette = palette;
        QSettings settings;
        settings.beginGroup(kSettingsGroup);
        settings.setValue(kPaletteKey, palette);
        settings.endGroup();
        emit thermalPaletteChanged();
    }
}

void ForeViewCamera::setThermalHighRange(bool highRange)
{
    if (!thermalSupported()) {
        return;
    }

    _send(kCmdSetThermalGain, highRange ? kGainLow : kGainHigh);

    if (highRange != _thermalHighRange) {
        _thermalHighRange = highRange;
        QSettings settings;
        settings.beginGroup(kSettingsGroup);
        settings.setValue(kHighRangeKey, highRange);
        settings.endGroup();
        emit thermalHighRangeChanged();
    }
}
